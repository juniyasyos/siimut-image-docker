#!/bin/sh
set -e

echo "🚀 Starting App (Production Registry Mode)"

APP_ENV="${APP_ENV:-production}"
if [ "${APP_ENV}" != "production" ]; then
    echo "⚠️ APP_ENV is '${APP_ENV}', overriding to 'production' for registry container"
    APP_ENV="production"
fi
APP_WORKDIR="${APP_WORKDIR:-/var/www/siimut}"
PUBLIC_VOLUME="${PUBLIC_VOLUME:-/var/www/public-shared}"

echo "📁 APP_WORKDIR=${APP_WORKDIR}"
cd "${APP_WORKDIR}"

# ------------------------------------------------------------------
# dynamic .env generation
# build a fresh .env from whatever environment variables are present
# this lets us push the same image and configure everything at runtime
# ------------------------------------------------------------------
echo "🧩 Generating .env from runtime environment variables"

# start from example so defaults are preserved; if none, create empty
if [ -f .env.example ]; then
    cp .env.example .env
else
    : > .env
fi

# helper that inserts or replaces a key in the file
set_env() {
    local key="$1" value="$2"
    if grep -q "^${key}=" .env 2>/dev/null; then
        sed -i "s~^${key}=.*~${key}=${value}~" .env
    else
        printf '%s=%s\n' "$key" "$value" >> .env
    fi
}

# list of variables we care about (add more as needed)
for var in APP_ENV APP_WORKDIR PUBLIC_VOLUME APP_URL DB_HOST DB_USERNAME DB_PASSWORD DB_DATABASE SKIP_PUBLIC_SYNC AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_BUCKET AWS_URL AWS_ENDPOINT USE_SSO IAM_ENABLED; do
    # expand the variable name stored in $var without adding extra spaces
    eval val=\${$var}
    if [ -n "$val" ]; then
        set_env "$var" "$val"
    fi
done

echo "✅ .env assembled"

# Validate Laravel
if [ ! -f artisan ]; then
    echo "❌ Laravel artisan not found in ${APP_WORKDIR}"
    exit 1
fi

# Validate .env - copy from .env.example if not exists
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo "📋 Copying .env.example to .env..."
        cp .env.example .env
        echo "✅ .env file created from .env.example"
    else
        echo "❌ .env and .env.example not found"
        exit 1
    fi
fi

# Ensure APP_KEY is set (generate if missing/empty)
APP_KEY_VALUE=$(grep -E '^APP_KEY=' .env | head -1 | cut -d'=' -f2- || true)
if [ -z "${APP_KEY_VALUE}" ]; then
    echo "🔐 Generating APP_KEY..."
    rm -rf bootstrap/cache/*.php
    php artisan key:generate --force
fi

# Run switch-auth-mode.sh if exists (for SIIMUT)
if [ -f "./switch-auth-mode.sh" ]; then
    echo "🔐 Setting authentication mode..."
    chmod +x ./switch-auth-mode.sh
    ./switch-auth-mode.sh dev || echo "⚠️ switch-auth-mode.sh failed (continuing...)"
fi

# Copy public assets to shared volume (only if PUBLIC_VOLUME is set and exists)
# Skip if SKIP_PUBLIC_SYNC is true or if source and destination are the same
if [ -n "${PUBLIC_VOLUME}" ] && [ -d "${PUBLIC_VOLUME}" ]; then
    
    # Check if we should skip sync
    if [ "${SKIP_PUBLIC_SYNC}" = "true" ]; then
        echo "ℹ️  SKIP_PUBLIC_SYNC=true, skipping public asset sync"
    else
        # Check if source and destination are the same
        SOURCE_REAL=$(cd "${APP_WORKDIR}/public" 2>/dev/null && pwd || echo "${APP_WORKDIR}/public")
        DEST_REAL=$(cd "${PUBLIC_VOLUME}" 2>/dev/null && pwd || echo "${PUBLIC_VOLUME}")
        
        if [ "${SOURCE_REAL}" = "${DEST_REAL}" ]; then
            echo "ℹ️  Source and destination are the same (shared volume), skipping sync"
        else
            echo "📦 Syncing public assets to ${PUBLIC_VOLUME}..."
            
            # Create target directory if not exists
            mkdir -p "${PUBLIC_VOLUME}"
            
            # Rsync or cp (rsync lebih efficient untuk update)
            if command -v rsync >/dev/null 2>&1; then
                rsync -a --delete "${APP_WORKDIR}/public/" "${PUBLIC_VOLUME}/"
                echo "✅ Public assets synced via rsync"
            else
                # Fallback to cp
                if [ -d "${PUBLIC_VOLUME}" ] && [ "$(ls -A ${PUBLIC_VOLUME} 2>/dev/null)" ]; then
                    rm -rf "${PUBLIC_VOLUME:?}"/*
                fi
                cp -r "${APP_WORKDIR}/public/." "${PUBLIC_VOLUME}/"
                echo "✅ Public assets copied"
            fi
            
            # Set permissions for Caddy to read
            chmod -R 755 "${PUBLIC_VOLUME}"
        fi
    fi
else
    echo "ℹ️  PUBLIC_VOLUME not set or doesn't exist, skipping public sync"
fi

# Wait for database
echo "⏳ Waiting for database..."
php -r '
$host    = getenv("DB_HOST") ?: "database-service";
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

# ------------------------------------------------------------------
# Wait for MinIO (S3 endpoint) to be available
# ------------------------------------------------------------------
echo "⏳ Waiting for MinIO service at ${AWS_ENDPOINT:-<unset>}"

# extract host and port; default port 80 if missing
minio_host=$(echo "${AWS_ENDPOINT}" | sed -E 's~https?://~~' | cut -d':' -f1)
minio_port=$(echo "${AWS_ENDPOINT}" | awk -F: '{print $NF}')
if [ -z "$minio_port" ] || [ "$minio_port" = "$minio_host" ]; then
    minio_port=80
fi

echo "🔍 Resolving host '$minio_host'..."
if getent hosts "$minio_host" >/dev/null 2>&1; then
    echo "✅ DNS lookup OK"
else
    echo "⚠️  DNS lookup failed for $minio_host"
fi

start=$(date +%s)
timeout=60
while true; do
    if curl -fsS --max-time 2 "${AWS_ENDPOINT}" >/dev/null 2>&1; then
        echo "✅ MinIO reachable at $minio_host:$minio_port"
        break
    fi
    if [ $(( $(date +%s) - start )) -gt $timeout ]; then
        echo "❌ Timeout waiting for MinIO ($timeout s)"
        break
    fi
    echo "… waiting for MinIO $minio_host:$minio_port"
    sleep 2
done


# Fix permissions BEFORE cache warming (penting!)
echo "🔧 Setting up permissions..."
if [ -d storage ]; then
  # Buat direktori cache jika belum ada
  mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views
  mkdir -p storage/logs storage/app/public
  mkdir -p bootstrap/cache
  
  # Create public/livewire symlink if not exists (Livewire asset serving)
  if [ ! -L public/livewire ]; then
    if [ -d public/vendor/livewire ]; then
      ln -s vendor/livewire public/livewire
      echo "✅ Created symlink: public/livewire -> vendor/livewire"
    else
      echo "📦 Publishing Livewire assets..."
      su-exec www php artisan livewire:publish --assets >/dev/null 2>&1 || true
      if [ -d public/vendor/livewire ]; then
        ln -s vendor/livewire public/livewire
        echo "✅ Livewire assets published and symlink created"
      fi
    fi
  fi 
  
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

# Laravel cache warming (run as www user)
echo "⚙️  Warming Laravel caches..."

# Clear all caches first to prevent stale/corrupted cache issues
echo "🧹 Clearing all caches..."
su-exec www php artisan cache:clear    >/dev/null 2>&1 || true
su-exec www php artisan config:clear   >/dev/null 2>&1 || true
su-exec www php artisan route:clear    >/dev/null 2>&1 || true
su-exec www php artisan view:clear     >/dev/null 2>&1 || true
su-exec www php artisan event:clear    >/dev/null 2>&1 || true

# Discover packages (was skipped at build time with --no-scripts)
echo "🔍 Running package:discover..."
su-exec www php artisan package:discover --ansi 2>&1 || echo "⚠️ package:discover failed"

# Rebuild caches (skip route:cache - Livewire routes incompatible with caching)
echo "♻️  Rebuilding caches..."
su-exec www php artisan config:cache   >/dev/null 2>&1 || echo "⚠️ config:cache failed"
# NOTE: Skipping route:cache due to Livewire compatibility issues
# su-exec www php artisan route:cache    >/dev/null 2>&1 || echo "⚠️ route:cache failed"
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

# show minio configuration so we can inspect at runtime
echo "🌐 Minio endpoint (AWS_ENDPOINT)=${AWS_ENDPOINT:-<unset>}"
echo "🌐 Minio bucket (AWS_BUCKET)=${AWS_BUCKET:-<unset>}"

# check port numbers extracted from AWS_ENDPOINT
if [ -n "${AWS_ENDPOINT}" ]; then
    port=$(echo "$AWS_ENDPOINT" | awk -F: '{print $NF}')
    echo "🔢 Minio endpoint port detected: $port"
    if [ "$port" != "9090" ]; then
        echo "⚠️  unexpected port for AWS_ENDPOINT (expected 9090)"
    fi
fi

# optionally show the console port separately (9091)
echo "🔐 Minio console is usually at port 9091 (not used by app)"

# attempt simple connectivity test (requires curl in image)
echo "🔗 Testing connectivity to Minio..."
if command -v curl >/dev/null 2>&1; then
    if curl -fsS --max-time 5 "${AWS_ENDPOINT:-}" >/dev/null 2>&1; then
        echo "✅ Able to reach Minio at ${AWS_ENDPOINT:-}"
    else
        echo "❌ Cannot reach Minio at ${AWS_ENDPOINT:-} (curl failed)"
    fi
else
    echo "⚠️  curl not available; skipping network check"
fi


# Execute main command
if [ $# -eq 0 ]; then
    set -- php-fpm -F
fi

echo "🚀 Starting: $*"
exec "$@"
