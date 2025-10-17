#!/bin/sh
set -e

echo "🚀 Starting SIIMUT Production Container (No Redis)..."

# Production environment check
if [ "$APP_ENV" = "production" ]; then
    echo "🏭 Production mode detected - Simple & Reliable"
    
    # Security: Remove development tools in production
    if command -v apk >/dev/null 2>&1; then
        apk del --no-cache git vim curl wget || true
    fi
else
    echo "⚠️  Non-production environment: $APP_ENV"
fi

# Wait for database with timeout
echo "⏳ Waiting for database connection..."
timeout=60
counter=0
while ! nc -z db 3306; do
    if [ $counter -ge $timeout ]; then
        echo "❌ Database connection timeout after ${timeout}s"
        exit 1
    fi
    echo "Waiting for database... (${counter}/${timeout}s)"
    sleep 2
    counter=$((counter + 2))
done
echo "✅ Database connection established!"

# Redis DISABLED - sehat, kenapa harus pakai obat
echo "ℹ️  Redis disabled - using database-based caching and sessions"
echo "💡 Simple approach: Database for cache, sessions, and queues"

# Validate Laravel project structure
if [ ! -f /var/www/html/artisan ]; then
    echo "❌ Laravel project not found in /var/www/html"
    echo "Make sure application folder is properly mounted"
    exit 1
fi

# Change to Laravel directory
cd /var/www/html

echo "🔧 Setting up Laravel application (Database-based)..."

# Production: Skip composer install if vendor exists (should be from image)
if [ "$APP_ENV" = "production" ] && [ -d "vendor" ]; then
    echo "✅ Using pre-built dependencies from image"
else
    # Development: Install dependencies
    if [ ! -d "vendor" ]; then
        echo "📦 Installing Composer dependencies..."
        if [ "$APP_ENV" = "production" ]; then
            composer install --no-dev --optimize-autoloader --no-interaction --no-progress
        else
            composer install --optimize-autoloader --no-interaction --no-progress
        fi
    fi
fi

# Environment setup with validation
if [ ! -f ".env" ]; then
    echo "⚙️  Setting up Laravel environment..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
    else
        echo "❌ No .env.example found!"
        exit 1
    fi
    
    # Generate application key
    php artisan key:generate --no-interaction --force
    
    # Configure database
    sed -i "s/DB_HOST=.*/DB_HOST=db/" .env
    sed -i "s/DB_DATABASE=.*/DB_DATABASE=${MYSQL_DATABASE:-siimut}/" .env
    sed -i "s/DB_USERNAME=.*/DB_USERNAME=${MYSQL_USER:-siimut}/" .env
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${MYSQL_PASSWORD:-secret}/" .env
    
    # Configure database-based caching and sessions (No Redis)
    sed -i "s/CACHE_DRIVER=.*/CACHE_DRIVER=database/" .env
    sed -i "s/SESSION_DRIVER=.*/SESSION_DRIVER=database/" .env
    sed -i "s/QUEUE_CONNECTION=.*/QUEUE_CONNECTION=database/" .env
    
    # Production environment settings
    if [ "$APP_ENV" = "production" ]; then
        sed -i "s/APP_ENV=.*/APP_ENV=production/" .env
        sed -i "s/APP_DEBUG=.*/APP_DEBUG=false/" .env
    fi
    
    echo "✅ Laravel environment configured for database-based operations!"
fi

# Validate APP_KEY exists
if ! grep -q "APP_KEY=base64:" .env 2>/dev/null; then
    echo "🔑 Generating missing application key..."
    php artisan key:generate --no-interaction --force
fi

# Set proper permissions
echo "📝 Setting proper permissions..."
if [ -d storage ]; then
    chown -R www:www storage
    chmod -R 775 storage
fi

if [ -d bootstrap/cache ]; then
    chown -R www:www bootstrap/cache 
    chmod -R 775 bootstrap/cache
fi

if [ -d public ]; then
    chown -R www:www public
    chmod -R 755 public
fi

# Test database connection
echo "🔍 Testing database connection..."
if ! php artisan tinker --execute="DB::connection()->getPdo();" >/dev/null 2>&1; then
    echo "⚠️  Database connection test failed (continuing anyway...)"
else
    echo "✅ Database connection test passed!"
fi

# Create required tables for database-based operations
echo "🗄️  Setting up database tables for cache/sessions/queues..."
php artisan migrate --force || echo "⚠️  Migrations failed (continuing...)"

# Laravel optimizations
echo "⚙️  Running Laravel optimizations..."

# Clear all caches first
php artisan config:clear || echo "Config clear failed"
php artisan route:clear || echo "Route clear failed" 
php artisan view:clear || echo "View clear failed"
php artisan cache:clear || echo "Cache clear failed"

# Rebuild caches
if [ "$APP_ENV" = "production" ]; then
    php artisan config:cache || echo "Config cache failed"
    php artisan route:cache || echo "Route cache failed"
    php artisan view:cache || echo "View cache failed"
    
    # Additional production optimizations
    php artisan event:cache || echo "Event cache failed"
    
    echo "✅ Production optimizations completed!"
else
    echo "✅ Development setup completed!"
fi

# Database setup for cache/sessions/queues
echo "🗃️  Setting up database tables..."
php artisan queue:table --force >/dev/null 2>&1 || echo "Queue table already exists"
php artisan session:table --force >/dev/null 2>&1 || echo "Session table already exists"  
php artisan cache:table --force >/dev/null 2>&1 || echo "Cache table already exists"

# Run migrations again to create tables
php artisan migrate --force || echo "⚠️  Final migrations failed (continuing...)"

# Create storage link
if [ ! -L public/storage ]; then
    echo "🔗 Creating storage symbolic link..."
    php artisan storage:link || echo "⚠️  Storage link failed (continuing...)"
fi

# Final permission check
chown -R www:www /var/www/html
find /var/www/html -type f -exec chmod 644 {} \; 2>/dev/null || true
find /var/www/html -type d -exec chmod 755 {} \; 2>/dev/null || true
chmod -R 775 storage bootstrap/cache 2>/dev/null || true

# Health check before starting
echo "🏥 Running health checks..."
if php artisan --version >/dev/null 2>&1; then
    echo "✅ Laravel framework check passed!"
else
    echo "❌ Laravel framework check failed!"
    exit 1
fi

echo "✅ All checks passed! Starting PHP-FPM..."
echo "💡 Using database for: cache, sessions, queues (Simple & Reliable)"
echo "📊 Container ready at: $(date)"

# Start the main process
exec "$@"