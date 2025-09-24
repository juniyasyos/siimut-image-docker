#!/usr/bin/env bash
set -euo pipefail

# entrypoint-production.sh — Lightweight production entrypoint for SIIMUT
#
# Optimized for:
# - Fast startup time
# - Minimal resource usage
# - Production security
# - Error handling
# - Cache optimization

APP_DIR="/var/www/html"
SIIMUT_DIR="$APP_DIR/si-imut"

# Simple logging
log() { echo "[$(date +'%H:%M:%S')] [siimut] $*"; }
error() { echo "[$(date +'%H:%M:%S')] [error] $*" >&2; }

# Default production settings
: "${APP_ENV:=production}"
: "${SIIMUT_WAIT_FOR_DB:=true}"
: "${SIIMUT_OPTIMIZE:=true}"

# Determine working directory
if [[ -d "$SIIMUT_DIR" ]] && [[ -f "$SIIMUT_DIR/artisan" ]]; then
  cd "$SIIMUT_DIR"
  APP_DIR="$SIIMUT_DIR"
elif [[ -d "$APP_DIR" ]] && [[ -f "$APP_DIR/artisan" ]]; then
  cd "$APP_DIR"
else
  error "Laravel application not found"
  exit 1
fi

log "🚀 Starting SIIMUT Production Container"

# Quick permission check and fix
if [[ ! -w storage ]] || [[ ! -w bootstrap/cache ]]; then
  log "📝 Fixing critical permissions"
  chmod -R ug+rw storage bootstrap/cache 2>/dev/null || true
fi

# Wait for database (production-critical)
if [[ "$SIIMUT_WAIT_FOR_DB" == "true" ]]; then
  DB_HOST="${DB_HOST:-$(grep "^DB_HOST=" .env 2>/dev/null | cut -d'=' -f2 || echo "db")}"
  DB_PORT="${DB_PORT:-$(grep "^DB_PORT=" .env 2>/dev/null | cut -d'=' -f2 || echo "3306")}"
  
  log "⏳ Waiting for database at $DB_HOST:$DB_PORT"
  timeout=60
  while ! nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; do
    if [[ $timeout -le 0 ]]; then
      error "Database not available after 60s"
      exit 1
    fi
    sleep 1
    timeout=$((timeout-1))
  done
  log "✅ Database ready"
fi

# Production optimizations (only if needed)
if [[ "$SIIMUT_OPTIMIZE" == "true" ]] && [[ -f artisan ]]; then
  # Check if already optimized
  if [[ ! -f bootstrap/cache/config.php ]] || [[ ! -f bootstrap/cache/routes.php ]]; then
    log "⚡ Applying production optimizations"
    php artisan config:cache 2>/dev/null || true
    php artisan route:cache 2>/dev/null || true
    php artisan view:cache 2>/dev/null || true
  fi
fi

# Essential directory structure
mkdir -p storage/{logs,framework/{sessions,views,cache}} bootstrap/cache 2>/dev/null || true

# Final permission normalization for www-data
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true

log "✅ Ready for production traffic"
exec "$@"