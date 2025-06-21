FROM php:8.4-fpm-alpine AS base

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

WORKDIR /

# Bersihkan dan clone project
RUN mkdir -p /var/www \
 && find /var/www -mindepth 1 -delete \
 && git clone https://github.com/juniyasyos/siimut-optimize.git /var/www 

# Set working directory
WORKDIR /var/www

# Jalankan composer install — ini akan otomatis memicu semua scripts yang kamu buat
RUN composer install \
&& npm install && npm run build \
&& composer run post-root-package-install \
&& composer run post-update-cmd \
&& composer run post-create-project-cmd

# Pastikan permission benar untuk Laravel
RUN chown -R www-data:www-data /var/www \
 && chmod -R ug+rw storage bootstrap/cache

# Edit file .env setelah clone dan sebelum artisan migrate
RUN sed -i 's/^APP_NAME=.*/APP_NAME="SIIMUT"/' .env \
 && sed -i 's/^APP_ENV=.*/APP_ENV=stagging/' .env \
 && sed -i 's/^APP_DEBUG=.*/APP_DEBUG=true/' .env \
 && sed -i 's/^DB_HOST=.*/DB_HOST=db/' .env \
 && sed -i 's/^DB_DATABASE=.*/DB_DATABASE=siimut_prod/' .env \
 && sed -i 's/^DB_USERNAME=.*/DB_USERNAME=siimut/' .env \
 && sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=password-siimut/' .env 

RUN git config --global --add safe.directory /var/www

EXPOSE 5173
