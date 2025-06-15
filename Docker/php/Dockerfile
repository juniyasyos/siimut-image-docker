FROM php:8.4-fpm AS base

COPY php.ini /usr/local/etc/php/
COPY docker.conf /usr/local/etc/php-fpm.d/docker.conf
COPY .bashrc /root/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

# Sistem dependency
RUN apt-get update \
  && apt-get install -y \
  build-essential zlib1g-dev default-mysql-client curl gnupg procps vim git unzip libzip-dev libpq-dev \
  libicu-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev

# PHP extensions
RUN docker-php-ext-configure intl \
  && docker-php-ext-install intl \
  && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
  && docker-php-ext-install gd zip pdo_mysql pdo_pgsql pgsql pcntl

# PECL extensions
RUN pecl install redis pcov \
  && docker-php-ext-enable redis pcov

# Node.js, NPM, Yarn
RUN curl -sL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y nodejs \
  && npm install -g npm@latest yarn

# Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
  && php composer-setup.php \
  && php -r "unlink('composer-setup.php');" \
  && mv composer.phar /usr/local/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/composer \
    PATH=$PATH:/composer/vendor/bin

RUN composer config --global process-timeout 3600 \
  && composer global require "laravel/installer"

EXPOSE 5173
