FROM php:7.2-apache

# install all the dependencies and enable PHP modules
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
      nano \
      git \
      unzip \
      libicu-dev \
      zlib1g-dev \
      libxml2 \
      libxml2-dev \
      libreadline-dev \
    && rm -r /var/lib/apt/lists/* \
    && docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
    && docker-php-ext-install \
      pdo_mysql \
      intl \
      zip && \
      apt-get clean && \
      rm -fr /tmp/* && \
      rm -rf /var/list/apt/*

# install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer

# create and set our application folder as an environment variable
RUN mkdir -p /var/www/laravel/public
ENV APP_HOME /var/www/laravel

# change uid and gid of apache to docker user uid/gid
RUN usermod -u 1000 www-data && groupmod -g 1000 www-data

# put apache and php configs for Laravel
COPY ./docker/hosts/laravel.conf /etc/apache2/sites-available/laravel.conf
RUN a2dissite 000-default.conf && a2ensite laravel.conf
COPY ./docker/production/php.ini /usr/local/etc/php/php.ini

# enable apache modules
RUN a2enmod rewrite

# copy source files and run composer
COPY . $APP_HOME

# set working dir
WORKDIR /var/www/laravel

# install all PHP dependencies
RUN composer install --no-interaction --no-progress --no-dev

# change ownership of our applications
RUN chown -R www-data:www-data $APP_HOME