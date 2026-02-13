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

# SYNC .env dari master file (development mode)
# Copy entire .env.dev.siimut atau .env.siimut ke .env
if [ -f "/var/www/env/.env.dev.siimut" ]; then
    echo "📋 Syncing .env from master file: /var/www/env/.env.dev.siimut"
    cp /var/www/env/.env.dev.siimut ./.env
    echo "✅ .env file synchronized"
elif [ -f "/var/www/env/.env.siimut" ]; then
    echo "📋 Syncing .env from master file: /var/www/env/.env.siimut (production)"
    cp /var/www/env/.env.siimut ./.env
    echo "✅ .env file synchronized"
else
    echo "⚠️  Master .env files not found at /var/www/env/ - using existing .env"
fi

# Run switch-auth-mode.sh if exists (for SIIMUT)
if [ -f "./switch-auth-mode.sh" ]; then
    echo "🔐 Setting authentication mode..."
    chmod +x ./switch-auth-mode.sh
    ./switch-auth-mode.sh dev || echo "⚠️ switch-auth-mode.sh failed (continuing...)"
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

# Fix permissions BEFORE cache warming (penting!)
echo "🔧 Setting up permissions..."
if [ -d storage ]; then
  # Buat direktori cache jika belum ada
  mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views
  mkdir -p storage/logs storage/app/public
  mkdir -p bootstrap/cache
  
  # Clear stale cache files yang mungkin corrupt atau orphaned
  echo "🧹 Cleaning stale cache files..."
  rm -rf storage/framework/views/*.php 2>/dev/null || true
  rm -rf storage/framework/cache/data/* 2>/dev/null || true
  rm -rf bootstrap/cache/*.php 2>/dev/null || true
  
  # Set ownership dan permission
  chown -R www:www storage bootstrap/cache 2>/dev/null || true
  chmod -R ug+rwX storage bootstrap/cache 2>/dev/null || true
  
  echo "✅ Permissions set"
fi

# Build Frontend Assets
echo "📦 Building frontend assets..."
if [ -f package.json ]; then
  echo "  📋 Running npm install..."
  npm install --no-save 2>&1 | tail -5
  
  echo "  🔨 Running npm run build..."
  npm run build 2>&1 | tail -10
  
  echo "✅ Frontend build complete"
else
  echo "⚠️  package.json not found, skipping npm build"
fi

# Laravel cache warming (run as www user)
echo "⚙️  Warming Laravel caches..."

# Clear all caches first to prevent stale/corrupted cache issues
echo "🧹 Clearing all caches..."
su-exec www php artisan cache:clear    >/dev/null 2>&1 || true
su-exec www php artisan config:clear   >/dev/null 2>&1 || true
su-exec www php artisan route:clear    >/dev/null 2>&1 || true
su-exec www php artisan view:clear     >/dev/null 2>&1 || true
su-exec www php artisan event:clear    >/dev/null 2>&1 || true

# Rebuild caches
echo "♻️  Rebuilding caches..."
su-exec www php artisan config:cache   >/dev/null 2>&1 || echo "⚠️ config:cache failed"
su-exec www php artisan route:cache    >/dev/null 2>&1 || echo "⚠️ route:cache failed"
su-exec www php artisan view:cache     >/dev/null 2>&1 || echo "⚠️ view:cache failed"
su-exec www php artisan event:cache    >/dev/null 2>&1 || echo "⚠️ event:cache failed"

# Run artisan optimize
echo "⚡ Running artisan optimize..."
su-exec www php artisan optimize       >/dev/null 2>&1 || echo "⚠️ artisan optimize failed"

# Verify critical directories are writable
echo "🔍 Verifying cache directories..."
for dir in storage/framework/views storage/framework/cache bootstrap/cache; do
  if [ -d "$dir" ] && [ ! -w "$dir" ]; then
    echo "⚠️ Warning: $dir is not writable"
  fi
done

echo "✅ IAM App ready at: $(date)"

# Execute main command
if [ $# -eq 0 ]; then
    set -- php-fpm -F
fi

echo "🚀 Starting: $*"
exec "$@"
