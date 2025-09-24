#!/usr/bin/env bash
set -euo pipefail

# entrypoint-enhanced.sh — Bootstrap komprehensif untuk container PHP-FPM Laravel SIIMUT
#
# Fitur:
# - Support multiple database types (MySQL/PostgreSQL/SQLite)
# - Composer management dengan retry mechanism
# - Smart environment configuration
# - Redis/cache optimization
# - Health checks dan monitoring
# - Permission handling yang robust
# - Migration dan seeding support
# - Storage management
# - Queue worker support

APP_DIR="/var/www/html"
SIIMUT_DIR="$APP_DIR/si-imut"

# Colors untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log() { echo -e "[$(date +'%H:%M:%S')] ${BLUE}[siimut]${NC} $*"; }
warn() { echo -e "[$(date +'%H:%M:%S')] ${YELLOW}[warn]${NC} $*"; }
error() { echo -e "[$(date +'%H:%M:%S')] ${RED}[error]${NC} $*" >&2; }
success() { echo -e "[$(date +'%H:%M:%S')] ${GREEN}[success]${NC} $*"; }

# Helper: artisan wrapper aman
artisan() {
  if [[ -f "$SIIMUT_DIR/artisan" ]]; then
    cd "$SIIMUT_DIR" && php artisan "$@"
  else
    warn "Lewati artisan $* (file artisan tidak ditemukan di $SIIMUT_DIR)"
    return 0
  fi
}

# Helper: composer dengan retry
composer_retry() {
  local tries=0 max=3 wait=2
  until composer "$@"; do
    tries=$((tries+1))
    if [[ $tries -ge $max ]]; then 
      error "Composer gagal setelah $max percobaan"
      return 1
    fi
    warn "Composer gagal, retry $tries/$max setelah ${wait}s..."
    sleep $wait
    wait=$((wait * 2)) # exponential backoff
  done
}

# Helper: wait for service
wait_for_service() {
  local host="$1" port="$2" service_name="$3" timeout="${4:-60}"
  local count=0
  log "Menunggu $service_name di $host:$port (timeout: ${timeout}s)"
  
  while ! nc -z "$host" "$port" 2>/dev/null; do
    if [[ $count -ge $timeout ]]; then
      error "$service_name tidak tersedia setelah ${timeout}s"
      return 1
    fi
    sleep 1
    count=$((count+1))
    [[ $((count % 10)) -eq 0 ]] && log "Masih menunggu $service_name... (${count}s)"
  done
  success "$service_name siap!"
}

# Helper: set .env value
set_env_value() {
  local key="$1" value="$2" env_file="${3:-$SIIMUT_DIR/.env}"
  [[ -f "$env_file" ]] || return 0
  
  if grep -qE "^${key}=" "$env_file"; then
    sed -i "s#^${key}=.*#${key}=${value}#" "$env_file"
  else
    echo "${key}=${value}" >> "$env_file"
  fi
}

# Helper: detect database type from environment
detect_db_type() {
  if [[ -n "${MYSQL_DATABASE:-}" ]] || [[ -n "${MYSQL_USER:-}" ]]; then
    echo "mysql"
  elif [[ -n "${POSTGRES_DB:-}" ]] || [[ -n "${POSTGRES_USER:-}" ]]; then
    echo "pgsql"
  elif [[ "${DB_CONNECTION:-}" == "sqlite" ]]; then
    echo "sqlite"
  else
    echo "${DB_CONNECTION:-mysql}" # default to mysql
  fi
}

# Environment variables with defaults
: "${APP_ENV:=production}"
: "${SIIMUT_WAIT_FOR_DB:=true}"
: "${SIIMUT_WAIT_FOR_REDIS:=true}"
: "${SIIMUT_RUN_MIGRATIONS:=false}"
: "${SIIMUT_RUN_SEEDERS:=false}"
: "${SIIMUT_STORAGE_LINK:=true}"
: "${SIIMUT_OPTIMIZE_CACHE:=true}"
: "${SIIMUT_QUEUE_WORKER:=false}"
: "${SIIMUT_DEBUG:=false}"

# Debug mode
[[ "$SIIMUT_DEBUG" == "true" ]] && set -x

log "🚀 Starting SIIMUT Container Bootstrap"
log "Environment: APP_ENV=$APP_ENV"

# Ensure we're in the right directory
if [[ -d "$SIIMUT_DIR" ]]; then
  cd "$SIIMUT_DIR"
  APP_DIR="$SIIMUT_DIR"
  log "Using SIIMUT Laravel directory: $SIIMUT_DIR"
elif [[ -d "$APP_DIR" ]] && [[ -f "$APP_DIR/artisan" ]]; then
  cd "$APP_DIR"
  log "Using Laravel directory: $APP_DIR"
else
  error "Laravel application tidak ditemukan di $APP_DIR atau $SIIMUT_DIR"
  exit 1
fi

# Clear Laravel bootstrap cache (safe even if vendor doesn't exist)
log "🧹 Clearing bootstrap cache"
rm -f bootstrap/cache/config.php bootstrap/cache/services.php bootstrap/cache/routes.php || true
if [[ -f artisan ]]; then
  php artisan config:clear 2>/dev/null || true
  php artisan cache:clear 2>/dev/null || true
fi

# Setup composer environment
export COMPOSER_CACHE_DIR="/tmp/composer-cache"
export COMPOSER_HOME="/tmp/composer-home"
export COMPOSER_TMP_DIR="/tmp"
mkdir -p "$COMPOSER_CACHE_DIR" "$COMPOSER_HOME"

# 1) Install/Update Composer dependencies
if [[ -f composer.json ]]; then
  log "📦 Checking Composer dependencies"
  mkdir -p vendor && chown -R www-data:www-data vendor 2>/dev/null || true
  
  if [[ ! -f vendor/autoload.php ]] || [[ composer.json -nt vendor/autoload.php ]]; then
    log "Installing/updating Composer dependencies"
    if [[ "$APP_ENV" == "production" ]]; then
      composer_retry install --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader --no-scripts
    else
      composer_retry install --prefer-dist --no-interaction --no-progress --no-scripts
    fi
    success "Composer dependencies installed"
  else
    log "Composer dependencies up to date"
  fi
else
  warn "composer.json tidak ditemukan"
fi

# 2) Setup .env file
log "⚙️ Configuring environment"
if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then
    cp .env.example .env
    log "Created .env from .env.example"
  else
    warn "Tidak ada .env maupun .env.example, membuat .env minimal"
    cat > .env << EOF
APP_NAME=SIIMUT
APP_ENV=${APP_ENV}
APP_KEY=
APP_DEBUG=false
APP_URL=http://localhost

LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=siimut
DB_USERNAME=siimut
DB_PASSWORD=secret

REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
EOF
  fi
fi

# 3) Auto-configure database based on environment
db_type=$(detect_db_type)
log "Database type detected: $db_type"

case "$db_type" in
  "mysql")
    set_env_value "DB_CONNECTION" "mysql"
    set_env_value "DB_HOST" "${DB_HOST:-db}"
    set_env_value "DB_PORT" "${DB_PORT:-3306}"
    set_env_value "DB_DATABASE" "${DB_DATABASE:-${MYSQL_DATABASE:-siimut}}"
    set_env_value "DB_USERNAME" "${DB_USERNAME:-${MYSQL_USER:-siimut}}"
    set_env_value "DB_PASSWORD" "${DB_PASSWORD:-${MYSQL_PASSWORD:-secret}}"
    ;;
  "pgsql")
    set_env_value "DB_CONNECTION" "pgsql"
    set_env_value "DB_HOST" "${DB_HOST:-db}"
    set_env_value "DB_PORT" "${DB_PORT:-5432}"
    set_env_value "DB_DATABASE" "${DB_DATABASE:-${POSTGRES_DB:-siimut}}"
    set_env_value "DB_USERNAME" "${DB_USERNAME:-${POSTGRES_USER:-siimut}}"
    set_env_value "DB_PASSWORD" "${DB_PASSWORD:-${POSTGRES_PASSWORD:-secret}}"
    ;;
  "sqlite")
    set_env_value "DB_CONNECTION" "sqlite"
    set_env_value "DB_DATABASE" "${DB_DATABASE:-/var/www/html/database/database.sqlite}"
    mkdir -p database
    touch "${DB_DATABASE:-database/database.sqlite}"
    ;;
esac

# Configure Redis if available
if [[ -n "${REDIS_HOST:-}" ]]; then
  set_env_value "REDIS_HOST" "${REDIS_HOST:-redis}"
  set_env_value "REDIS_PORT" "${REDIS_PORT:-6379}"
  set_env_value "REDIS_PASSWORD" "${REDIS_PASSWORD:-null}"
  set_env_value "CACHE_DRIVER" "redis"
  set_env_value "SESSION_DRIVER" "redis"
  set_env_value "QUEUE_CONNECTION" "redis"
fi

# 4) Setup directories and permissions
log "📁 Setting up directories and permissions"
mkdir -p storage/{app,framework/{cache,sessions,views},logs} bootstrap/cache || true

# Try to set proper ownership
if command -v chown >/dev/null 2>&1; then
  chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
fi

# Set permissions
chmod -R ug+rwX storage bootstrap/cache || true

# Fallback for problematic environments (Windows bind mounts, etc.)
if ! ( : > storage/framework/views/.perm_test 2>/dev/null ); then
  warn "Permission issues detected, applying fallback permissions"
  chmod -R 0777 storage bootstrap/cache 2>/dev/null || true
fi
rm -f storage/framework/views/.perm_test 2>/dev/null || true

# 5) Wait for external services
if [[ "$SIIMUT_WAIT_FOR_DB" == "true" ]] && [[ "$db_type" != "sqlite" ]]; then
  DB_HOST=$(grep "^DB_HOST=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
  DB_PORT=$(grep "^DB_PORT=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
  
  if [[ -n "$DB_HOST" ]] && [[ -n "$DB_PORT" ]]; then
    wait_for_service "$DB_HOST" "$DB_PORT" "Database ($db_type)"
  fi
fi

if [[ "$SIIMUT_WAIT_FOR_REDIS" == "true" ]]; then
  REDIS_HOST=$(grep "^REDIS_HOST=" .env 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "")
  REDIS_PORT=$(grep "^REDIS_PORT=" .env 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "6379")
  
  if [[ -n "$REDIS_HOST" ]]; then
    wait_for_service "$REDIS_HOST" "$REDIS_PORT" "Redis" 30 || warn "Redis tidak tersedia, melanjutkan tanpa Redis"
  fi
fi

# 6) Generate APP_KEY if needed
if [[ -f .env ]]; then
  if ! grep -qE '^APP_KEY=.+$' .env; then
    log "🔑 Generating APP_KEY"
    if [[ -f artisan ]] && [[ -f vendor/autoload.php ]]; then
      php artisan key:generate --force || {
        warn "artisan key:generate gagal, menggunakan fallback manual"
        KEY=$(php -r 'echo "base64:".base64_encode(random_bytes(32));')
        set_env_value "APP_KEY" "$KEY"
      }
    else
      log "Generating APP_KEY manually (artisan not available)"
      KEY=$(php -r 'echo "base64:".base64_encode(random_bytes(32));')
      set_env_value "APP_KEY" "$KEY"
    fi
    success "APP_KEY generated"
  fi
fi

# 7) Create storage link
if [[ "$SIIMUT_STORAGE_LINK" == "true" ]] && [[ -f artisan ]]; then
  if [[ ! -e public/storage ]] && [[ -d storage/app/public ]]; then
    log "🔗 Creating storage link"
    php artisan storage:link || warn "Storage link creation failed"
  fi
fi

# 8) Run optimizations
if [[ -f artisan ]] && [[ -f vendor/autoload.php ]]; then
  if [[ "$SIIMUT_OPTIMIZE_CACHE" == "true" ]]; then
    if [[ "$APP_ENV" == "production" ]]; then
      log "🚀 Optimizing for production"
      php artisan config:cache || warn "Config cache failed"
      php artisan route:cache || warn "Route cache failed"
      php artisan view:cache || warn "View cache failed"
      
      if command -v composer >/dev/null; then
        composer dump-autoload --optimize --no-interaction || warn "Composer optimize failed"
      fi
    else
      log "🧹 Clearing caches for development"
      php artisan config:clear || true
      php artisan route:clear || true
      php artisan view:clear || true
      php artisan cache:clear || true
    fi
  fi
fi

# 9) Run migrations and seeders if requested
if [[ "$SIIMUT_RUN_MIGRATIONS" == "true" ]] && [[ -f artisan ]]; then
  log "🗄️ Running database migrations"
  php artisan migrate --force || warn "Migrations failed"
fi

if [[ "$SIIMUT_RUN_SEEDERS" == "true" ]] && [[ -f artisan ]]; then
  log "🌱 Running database seeders"
  php artisan db:seed --force || warn "Seeders failed"
fi

# 10) Final permission fixes
if command -v chown >/dev/null 2>&1; then
  chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
fi
chmod -R ug+rwX storage bootstrap/cache || true

# 11) Health check
log "🏥 Running health check"
if [[ -f artisan ]] && [[ -f vendor/autoload.php ]]; then
  php artisan --version >/dev/null && success "Laravel is ready"
else
  warn "Laravel health check failed"
fi

success "✅ SIIMUT Bootstrap completed successfully!"

# 12) Start queue worker if requested (background)
if [[ "$SIIMUT_QUEUE_WORKER" == "true" ]] && [[ -f artisan ]]; then
  log "🔄 Starting queue worker in background"
  nohup php artisan queue:work --sleep=3 --tries=3 --timeout=60 > /var/log/queue-worker.log 2>&1 &
fi

log "🌐 Starting main process: $*"
exec "$@"