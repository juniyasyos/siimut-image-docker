#!/bin/sh
set -e

echo "🚀 Starting SIIMUT Container..."

# Install required PHP extensions if not exists
if ! php -m | grep -q pdo_mysql; then
    echo "📦 Installing PHP extensions..."
    apk add --no-cache \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        libzip-dev \
        icu-dev \
        oniguruma-dev \
        postgresql-dev \
        $PHPIZE_DEPS
    
    docker-php-ext-configure gd --with-freetype --with-jpeg
    docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mysqli \
        gd \
        zip \
        intl \
        mbstring \
        opcache \
        bcmath \
        exif
    
    # Install Redis extension
    pecl install redis
    docker-php-ext-enable redis
    
    echo "✅ PHP extensions installed!"
fi

# Install Composer if not exists
if ! command -v composer > /dev/null; then
    echo "📦 Installing Composer..."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    echo "✅ Composer installed!"
fi

# Wait for database
echo "⏳ Waiting for database..."
while ! nc -z db 3306; do
    echo "Waiting for database connection..."
    sleep 2
done
echo "✅ Database is ready!"

# Check if Laravel project exists
if [ ! -f /var/www/artisan ]; then
    echo "⚠️  Laravel project not found in /var/www"
    echo "Make sure application folder is properly mounted"
    exit 1
fi

# Change to Laravel directory
cd /var/www

echo "🔧 Setting up Laravel application..."

# Install dependencies if vendor not exists
if [ ! -d "vendor" ]; then
    echo "📦 Installing Composer dependencies..."
    composer install --no-dev --optimize-autoloader --no-interaction
fi

# Setup Laravel if not configured
if [ ! -f ".env" ]; then
    echo "⚙️  Setting up Laravel environment..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
    else
        echo "⚠️  No .env.example found!"
        exit 1
    fi
    
    php artisan key:generate --no-interaction
    
    # Set database configuration
    sed -i "s/DB_HOST=.*/DB_HOST=db/" .env
    sed -i "s/DB_DATABASE=.*/DB_DATABASE=${MYSQL_DATABASE:-siimut}/" .env
    sed -i "s/DB_USERNAME=.*/DB_USERNAME=${MYSQL_USER:-siimut}/" .env
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${MYSQL_PASSWORD:-secret}/" .env
    
    # Set Redis configuration
    sed -i "s/REDIS_HOST=.*/REDIS_HOST=redis/" .env
    sed -i "s/CACHE_DRIVER=.*/CACHE_DRIVER=redis/" .env
    sed -i "s/SESSION_DRIVER=.*/SESSION_DRIVER=redis/" .env
    sed -i "s/QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/" .env
    
    echo "✅ Laravel environment configured!"
fi

# Fix permissions first
echo "📝 Fixing permissions..."
if [ -d storage ]; then
    chown -R www-data:www-data storage
    chmod -R 775 storage
fi

if [ -d bootstrap/cache ]; then
    chown -R www-data:www-data bootstrap/cache
    chmod -R 775 bootstrap/cache
fi

# Setup sessions directory for phpMyAdmin
mkdir -p /sessions
chmod 777 /sessions

# Generate app key if not exists
if ! grep -q "APP_KEY=base64:" .env 2>/dev/null; then
    echo "🔑 Generating application key..."
    php artisan key:generate --no-interaction
fi

# Run Laravel optimizations
echo "⚙️  Optimizing Laravel..."
php artisan config:cache || echo "Config cache failed (continuing...)"
php artisan route:cache || echo "Route cache failed (continuing...)"
php artisan view:cache || echo "View cache failed (continuing...)"

# Run migrations if in development
if [ "$APP_ENV" = "local" ] || [ "$APP_ENV" = "staging" ]; then
    echo "🗄️  Running database migrations..."
    php artisan migrate --force || echo "Migrations failed (continuing...)"
fi

# Create storage link
if [ ! -L public/storage ]; then
    echo "🔗 Creating storage link..."
    php artisan storage:link || echo "Storage link failed (continuing...)"
fi

# Set final permissions
chown -R www-data:www-data /var/www
chmod -R ug+rw storage bootstrap/cache 2>/dev/null || true

echo "✅ Laravel setup completed!"
echo "🌐 Starting PHP-FPM..."

# Start PHP-FPM
exec "$@"
