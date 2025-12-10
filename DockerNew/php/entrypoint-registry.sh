#!/bin/sh
set -e

echo "🚀 Starting IAM App (Production Registry Mode)"

APP_ENV="${APP_ENV:-production}"
APP_WORKDIR="${APP_WORKDIR:-/var/www/iam}"
PUBLIC_VOLUME="${PUBLIC_VOLUME:-/var/www/public-shared}"

echo "📁 APP_WORKDIR=${APP_WORKDIR}"
cd "${APP_WORKDIR}"

# Validate Laravel
if [ ! -f artisan ]; then
    echo "❌ Laravel artisan not found in ${APP_WORKDIR}"
    exit 1
fi

# Validate .env
if [ "$APP_ENV" = "production" ] && [ ! -f ".env" ]; then
    echo "❌ .env not found in production mode"
    exit 1
fi

# Copy public assets to shared volume for Caddy (only if PUBLIC_VOLUME is set and exists)
if [ -n "${PUBLIC_VOLUME}" ] && [ -d "${PUBLIC_VOLUME}" ]; then
    echo "📦 Syncing public assets to ${PUBLIC_VOLUME}..."
    
    # Create target directory if not exists
    mkdir -p "${PUBLIC_VOLUME}"
    
    # Rsync or cp (rsync lebih efficient untuk update)
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "${APP_WORKDIR}/public/" "${PUBLIC_VOLUME}/"
        echo "✅ Public assets synced via rsync"
    else
        # Fallback to cp
        rm -rf "${PUBLIC_VOLUME:?}"/*
        cp -r "${APP_WORKDIR}/public/." "${PUBLIC_VOLUME}/"
        echo "✅ Public assets copied"
    fi
    
    # Set permissions for Caddy to read
    chmod -R 755 "${PUBLIC_VOLUME}"
else
    echo "ℹ️  PUBLIC_VOLUME not set or doesn't exist, skipping public sync"
fi

# Wait for database
echo "⏳ Waiting for database..."
php -r '
$host    = getenv("DB_HOST") ?: "db";
$port    = getenv("DB_PORT") ?: 3306;
$timeout = 60;
$start   = time();

while (true) {
    $fp = @fsockopen($host, $port, $errno, $errstr, 2);
    if ($fp) {
        fclose($fp);
        fwrite(STDOUT, "✅ Database connected: {$host}:{$port}\n");
        break;
    }
    if (time() - $start > $timeout) {
        fwrite(STDERR, "❌ Database timeout after {$timeout}s\n");
        exit(1);
    }
    fwrite(STDOUT, "… waiting for DB {$host}:{$port}\n");
    sleep(2);
}
'

# Laravel cache warming
echo "⚙️  Warming Laravel caches..."
php artisan config:cache   >/dev/null 2>&1 || echo "⚠️ config:cache failed"
php artisan route:cache    >/dev/null 2>&1 || echo "⚠️ route:cache failed"
php artisan view:cache     >/dev/null 2>&1 || echo "⚠️ view:cache failed"
php artisan event:cache    >/dev/null 2>&1 || echo "⚠️ event:cache failed"

# Fix permissions
if [ -d storage ]; then
  chown -R www:www storage bootstrap/cache 2>/dev/null || true
  chmod -R ug+rwX storage bootstrap/cache 2>/dev/null || true
fi

echo "✅ IAM App ready at: $(date)"

# Execute main command
if [ $# -eq 0 ]; then
    set -- php-fpm -F
fi

echo "🚀 Starting: $*"
exec "$@"
