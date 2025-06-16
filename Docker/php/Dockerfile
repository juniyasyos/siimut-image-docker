FROM php:8.4-fpm AS base

# --- Konfigurasi awal ---
COPY php.ini /usr/local/etc/php/
COPY docker.conf /usr/local/etc/php-fpm.d/docker.conf
COPY .bashrc /root/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

# --- Instalasi sistem dependency ---
RUN apt-get update && apt-get install -y \
  build-essential zlib1g-dev default-mysql-client curl gnupg procps vim git unzip libzip-dev libpq-dev \
  libicu-dev libfreetype6-dev libjpeg62-turbo-dev libpng-dev

# --- PHP extensions ---
RUN docker-php-ext-configure intl \
  && docker-php-ext-install intl \
  && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
  && docker-php-ext-install gd zip pdo_mysql pdo_pgsql pgsql pcntl exif

# --- PECL extensions ---
RUN pecl install redis pcov \
  && docker-php-ext-enable redis pcov

# --- Instalasi Node.js, npm, dan Yarn ---
RUN curl -sL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y nodejs \
  && npm install -g npm@latest yarn

# --- Instalasi Composer ---
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
  && php composer-setup.php \
  && php -r "unlink('composer-setup.php');" \
  && mv composer.phar /usr/local/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/composer \
    PATH=$PATH:/composer/vendor/bin

# --- Laravel installer & buat project dari GitHub repo pribadi ---
RUN composer config --global process-timeout 3600 \
  && composer global require laravel/installer

# Pindah ke direktori sementara sebelum menghapus isi /var/www
WORKDIR /tmp

# Hapus isi /var/www dengan aman dan buat project
RUN find /var/www -mindepth 1 -delete && composer create-project juniyasyos/siimut /var/www

# Balikkan WORKDIR ke /var/www
WORKDIR /var/www

RUN chown -R www-data:www-data /var/www \
    && chmod -R 775 /var/www/storage /var/www/bootstrap/cache

EXPOSE 5173
