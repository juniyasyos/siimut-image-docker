#!/bin/sh
set -e

echo "🚀 Starting SIIMUT Container..."

# Wait for database to be ready
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

# Check and setup Laravel dependencies
if [ ! -d vendor ]; then
    echo "📦 Installing Composer dependencies..."
    composer install --no-dev --optimize-autoloader --no-interaction
fi

# Check .env file
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "✅ Created .env from .env.example"
    else
        echo "⚠️  No .env file found!"
    fi
fi

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