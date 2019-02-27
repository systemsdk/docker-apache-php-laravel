FROM php:7.3-apache

# set main params
ARG BUILD_ARGUMENT_DEBUG_ENABLED=false
ENV DEBUG_ENABLED=$BUILD_ARGUMENT_DEBUG_ENABLED
ARG BUILD_ARGUMENT_ENV=dev
ENV ENV=$BUILD_ARGUMENT_ENV
ENV APP_HOME /var/www/html

# check environment
RUN if [ "$BUILD_ARGUMENT_ENV" = "default" ]; then echo "Set BUILD_ARGUMENT_ENV in docker build-args like --build-arg BUILD_ARGUMENT_ENV=dev" && exit 2; \
    elif [ "$BUILD_ARGUMENT_ENV" = "dev" ]; then echo "Building development environment."; \
    elif [ "$BUILD_ARGUMENT_ENV" = "test" ]; then echo "Building test environment."; \
    elif [ "$BUILD_ARGUMENT_ENV" = "prod" ]; then echo "Building production environment."; \
    else echo "Set correct BUILD_ARGUMENT_ENV in docker build-args like --build-arg BUILD_ARGUMENT_ENV=dev. Available choices are dev,test,prod." && exit 2; \
    fi

# install all the dependencies and enable PHP modules
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
      procps \
      nano \
      git \
      unzip \
      libicu-dev \
      zlib1g-dev \
      libxml2 \
      libxml2-dev \
      libreadline-dev \
      supervisor \
      cron \
      libzip-dev \
    && docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
    && docker-php-ext-install \
      pdo_mysql \
      intl \
      zip && \
      rm -fr /tmp/* && \
      rm -rf /var/list/apt/* && \
      rm -r /var/lib/apt/lists/* && \
      apt-get clean

# disable default site and delete all default files inside APP_HOME
RUN a2dissite 000-default.conf
RUN rm -r $APP_HOME

# create document root
RUN mkdir -p $APP_HOME/public

# change uid and gid of apache to docker user uid/gid
RUN usermod -u 1000 www-data && groupmod -g 1000 www-data
RUN chown -R www-data:www-data $APP_HOME

# put apache and php config for Laravel, enable sites
COPY ./docker/hosts/laravel.conf /etc/apache2/sites-available/laravel.conf
COPY ./docker/hosts/laravel-ssl.conf /etc/apache2/sites-available/laravel-ssl.conf
RUN a2ensite laravel.conf && a2ensite laravel-ssl
COPY ./docker/$BUILD_ARGUMENT_ENV/php.ini /usr/local/etc/php/php.ini

# enable apache modules
RUN a2enmod rewrite
RUN a2enmod ssl

# install Xdebug in case development environment
COPY ./docker/other/do_we_need_xdebug.sh /tmp/
COPY ./docker/dev/xdebug.ini /tmp/
RUN chmod u+x /tmp/do_we_need_xdebug.sh && /tmp/do_we_need_xdebug.sh

# install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer

# add supervisor
RUN mkdir -p /var/log/supervisor
COPY --chown=root:root ./docker/other/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY --chown=root:root ./docker/other/cron /var/spool/cron/crontabs/root
RUN chmod 0600 /var/spool/cron/crontabs/root

# generate certificates
# TODO: change it and make additional logic for production environment
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/ssl-cert-snakeoil.key -out /etc/ssl/certs/ssl-cert-snakeoil.pem -subj "/C=AT/ST=Vienna/L=Vienna/O=Security/OU=Development/CN=example.com"

# set working directory
WORKDIR $APP_HOME

# create composer folder for user www-data
RUN mkdir -p /var/www/.composer && chown -R www-data:www-data /var/www/.composer

USER www-data

# copy source files and config file
COPY --chown=www-data:www-data . $APP_HOME/
COPY --chown=www-data:www-data .env.$ENV $APP_HOME/.env

# install all PHP dependencies
RUN if [ "$BUILD_ARGUMENT_ENV" = "dev" ] || [ "$BUILD_ARGUMENT_ENV" = "test" ]; then composer install --no-interaction --no-progress; \
    else composer install --no-interaction --no-progress --no-dev; \
    fi

USER root
