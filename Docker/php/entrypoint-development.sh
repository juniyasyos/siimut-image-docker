#!/usr/bin/env bash
set -euo pipefail

# entrypoint-development.sh — Development-focused entrypoint untuk SIIMUT
#
# Fitur development:
# - Hot reload support
# - Development packages
# - Debugging tools
# - Flexible permissions
# - Auto-migrations
# - Seeding support
# - File watching

APP_DIR="/var/www/html"
SIIMUT_DIR="$APP_DIR/si-imut"

# Colors untuk development
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() { echo -e "[$(date +'%H:%M:%S')] ${BLUE}[dev]${NC} $*"; }
warn() { echo -e "[$(date +'%H:%M:%S')] ${YELLOW}[warn]${NC} $*"; }
error() { echo -e "[$(date +'%H:%M:%S')] ${RED}[error]${NC} $*" >&2; }
success() { echo -e "[$(date +'%H:%M:%S')] ${GREEN}[success]${NC} $*"; }
debug() { echo -e "[$(date +'%H:%M:%S')] ${PURPLE}[debug]${NC} $*"; }

# Development defaults
: "${APP_ENV:=local}"
: "${APP_DEBUG:=true}"
: "${SIIMUT_WAIT_FOR_DB:=true}"
: "${SIIMUT_AUTO_MIGRATE:=true}"
: "${SIIMUT_AUTO_SEED:=false}"
: "${SIIMUT_INSTALL_DEV_DEPS:=true}"
: "${SIIMUT_CLEAR_CACHE:=true}"
: "${SIIMUT_ENABLE_XDEBUG:=false}"

# Determine app directory
if [[ -d "$SIIMUT_DIR" ]]; then
  cd "$SIIMUT_DIR"
  APP_DIR="$SIIMUT_DIR"
  log "Using SIIMUT development directory: $SIIMUT_DIR"
elif [[ -d "$APP_DIR" ]] && [[ -f "$APP_DIR/artisan" ]]; then
  cd "$APP_DIR"
  log "Using Laravel development directory: $APP_DIR"
else
  error "Laravel application tidak ditemukan untuk development"
  exit 1
fi

log "🛠️  Starting SIIMUT Development Container"
log "Environment: APP_ENV=$APP_ENV, DEBUG=$APP_DEBUG"

# Setup composer for development
export COMPOSER_CACHE_DIR="/tmp/composer-cache"
export COMPOSER_HOME="/tmp/composer-home"
mkdir -p "$COMPOSER_CACHE_DIR" "$COMPOSER_HOME"

# Install/update development dependencies
if [[ "$SIIMUT_INSTALL_DEV_DEPS" == "true" ]] && [[ -f composer.json ]]; then
  log "📦 Installing development dependencies"
  if [[ ! -d vendor ]] || [[ composer.json -nt composer.lock ]]; then
    composer install --prefer-dist --no-interaction --no-progress
    success "Development dependencies installed"
  else
    log "Development dependencies up to date"
  fi
fi

# Setup .env for development
if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then
    cp .env.example .env
    log "Created .env from .env.example"
  else
    warn "Creating minimal development .env"
    cat > .env << EOF
APP_NAME="SIIMUT Development"
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://localhost

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=siimut
DB_USERNAME=siimut
DB_PASSWORD=secret

REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

CACHE_DRIVER=array
SESSION_DRIVER=file
QUEUE_CONNECTION=sync

MAIL_MAILER=log
EOF
  fi
fi

# Configure for development
if [[ -f .env ]]; then
  sed -i "s/^APP_ENV=.*/APP_ENV=local/" .env
  sed -i "s/^APP_DEBUG=.*/APP_DEBUG=true/" .env
  sed -i "s/^LOG_LEVEL=.*/LOG_LEVEL=debug/" .env
  # Use file-based cache for development to avoid Redis dependency
  sed -i "s/^CACHE_DRIVER=.*/CACHE_DRIVER=array/" .env
  sed -i "s/^SESSION_DRIVER=.*/SESSION_DRIVER=file/" .env
  sed -i "s/^QUEUE_CONNECTION=.*/QUEUE_CONNECTION=sync/" .env
fi

# Very permissive permissions for development
log "📁 Setting up development permissions (permissive)"
mkdir -p storage/{app,framework/{cache,sessions,views},logs} bootstrap/cache || true
chmod -R 0777 storage bootstrap/cache 2>/dev/null || true

# Wait for database with shorter timeout for development
if [[ "$SIIMUT_WAIT_FOR_DB" == "true" ]]; then
  DB_HOST="${DB_HOST:-db}"
  DB_PORT="${DB_PORT:-3306}"
  log "⏳ Waiting for development database at $DB_HOST:$DB_PORT"
  
  timeout=30
  while ! nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; do
    if [[ $timeout -le 0 ]]; then
      warn "Database not ready after 30s, continuing anyway (development mode)"
      break
    fi
    sleep 1
    timeout=$((timeout-1))
  done
  
  if nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; then
    success "Database ready"
  fi
fi

# Generate APP_KEY
if [[ -f .env ]] && ! grep -qE '^APP_KEY=.+$' .env; then
  log "🔑 Generating development APP_KEY"
  if [[ -f artisan ]] && [[ -f vendor/autoload.php ]]; then
    php artisan key:generate --force || true
  else
    KEY=$(php -r 'echo "base64:".base64_encode(random_bytes(32));')
    sed -i "s/^APP_KEY=.*/APP_KEY=$KEY/" .env
  fi
fi

# Clear all caches for development
if [[ "$SIIMUT_CLEAR_CACHE" == "true" ]] && [[ -f artisan ]]; then
  log "🧹 Clearing all caches for development"
  php artisan config:clear 2>/dev/null || true
  php artisan route:clear 2>/dev/null || true
  php artisan view:clear 2>/dev/null || true
  php artisan cache:clear 2>/dev/null || true
  # Clear compiled files
  rm -f bootstrap/cache/config.php bootstrap/cache/services.php bootstrap/cache/routes.php || true
fi

# Create storage link
if [[ -f artisan ]] && [[ ! -e public/storage ]] && [[ -d storage/app/public ]]; then
  log "🔗 Creating storage link"
  php artisan storage:link || warn "Storage link failed"
fi

# Auto-migrate in development
if [[ "$SIIMUT_AUTO_MIGRATE" == "true" ]] && [[ -f artisan ]] && nc -z "${DB_HOST:-db}" "${DB_PORT:-3306}" 2>/dev/null; then
  log "🗄️ Running development migrations"
  php artisan migrate --force 2>/dev/null || warn "Migrations failed (continuing)"
fi

# Auto-seed in development
if [[ "$SIIMUT_AUTO_SEED" == "true" ]] && [[ -f artisan ]] && nc -z "${DB_HOST:-db}" "${DB_PORT:-3306}" 2>/dev/null; then
  log "🌱 Running development seeders"
  php artisan db:seed --force 2>/dev/null || warn "Seeders failed (continuing)"
fi

# Enable Xdebug if requested
if [[ "$SIIMUT_ENABLE_XDEBUG" == "true" ]]; then
  log "🐛 Enabling Xdebug for development"
  if php -m | grep -q xdebug; then
    cat >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini << EOF
xdebug.mode=develop,debug,coverage
xdebug.client_host=host.docker.internal
xdebug.client_port=9003
xdebug.start_with_request=yes
xdebug.log=/var/log/xdebug.log
EOF
    success "Xdebug enabled"
  else
    warn "Xdebug not installed, skipping"
  fi
fi

# Show useful development information
if [[ -f artisan ]]; then
  log "📋 Development Information:"
  debug "Laravel version: $(php artisan --version 2>/dev/null || echo 'Unknown')"
  debug "PHP version: $(php -v | head -n1)"
  debug "Working directory: $(pwd)"
  debug "Environment file: $(ls -la .env 2>/dev/null || echo '.env not found')"
fi

# Final permission fix for www-data
chown -R www-data:www-data . 2>/dev/null || true

success "✅ Development environment ready!"
log "🌐 Starting development server: $*"

exec "$@"