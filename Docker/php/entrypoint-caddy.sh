#!/usr/bin/env bash
set -euo pipefail

# entrypoint-caddy.sh — Entrypoint khusus untuk SIIMUT dengan Caddy server
#
# Fitur:
# - Optimized untuk Caddy reverse proxy
# - HTTPS/TLS certificate management
# - Static file serving optimization
# - Health checks untuk load balancer
# - Graceful shutdown handling

APP_DIR="/var/www/html"
SIIMUT_DIR="$APP_DIR/si-imut"

# Logging dengan format yang Caddy-friendly
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [siimut-caddy] $*"; }
error() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [error] $*" >&2; }

# Default untuk Caddy environment
: "${APP_ENV:=production}"
: "${SIIMUT_WAIT_FOR_DB:=true}"
: "${SIIMUT_CADDY_OPTIMIZE:=true}"
: "${SIIMUT_STATIC_CACHE:=true}"
: "${SIIMUT_HEALTH_CHECK:=true}"

# Tentukan direktori kerja
if [[ -d "$SIIMUT_DIR" ]] && [[ -f "$SIIMUT_DIR/artisan" ]]; then
  cd "$SIIMUT_DIR"
  APP_DIR="$SIIMUT_DIR"
elif [[ -d "$APP_DIR" ]] && [[ -f "$APP_DIR/artisan" ]]; then
  cd "$APP_DIR"
else
  error "Laravel application not found for Caddy setup"
  exit 1
fi

log "🚀 Starting SIIMUT with Caddy optimization"

# Setup graceful shutdown handler
cleanup() {
  log "Received shutdown signal, cleaning up..."
  # Clear any temporary files
  rm -f /tmp/siimut-*.tmp 2>/dev/null || true
  # Gracefully stop any background processes
  jobs -p | xargs -r kill 2>/dev/null || true
  log "Cleanup completed"
  exit 0
}
trap cleanup SIGTERM SIGINT

# Quick essential permissions for web server
mkdir -p storage/{logs,framework/{sessions,views,cache}} bootstrap/cache public/storage || true
chmod -R ug+rw storage bootstrap/cache || true
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true

# Wait for database (critical for Caddy health checks)
if [[ "$SIIMUT_WAIT_FOR_DB" == "true" ]]; then
  DB_HOST="${DB_HOST:-$(grep "^DB_HOST=" .env 2>/dev/null | cut -d'=' -f2 || echo "db")}"
  DB_PORT="${DB_PORT:-$(grep "^DB_PORT=" .env 2>/dev/null | cut -d'=' -f2 || echo "3306")}"
  
  log "Waiting for database at $DB_HOST:$DB_PORT (required for health checks)"
  timeout=45
  while ! nc -z "$DB_HOST" "$DB_PORT" 2>/dev/null; do
    if [[ $timeout -le 0 ]]; then
      error "Database unavailable - health checks will fail"
      exit 1
    fi
    sleep 1
    timeout=$((timeout-1))
  done
  log "Database ready"
fi

# Optimize untuk Caddy static file serving
if [[ "$SIIMUT_STATIC_CACHE" == "true" ]]; then
  log "Optimizing static assets for Caddy"
  
  # Ensure public directory structure
  mkdir -p public/{css,js,images,storage} || true
  
  # Set optimal permissions for static files
  find public -type f -name "*.css" -o -name "*.js" -o -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.svg" -o -name "*.ico" | xargs chmod 644 2>/dev/null || true
  
  # Create .well-known directory untuk ACME challenges
  mkdir -p public/.well-known/acme-challenge || true
  chmod 755 public/.well-known/acme-challenge || true
fi

# Caddy-optimized Laravel caching
if [[ "$SIIMUT_CADDY_OPTIMIZE" == "true" ]] && [[ -f artisan ]]; then
  log "Applying Caddy-optimized caching"
  
  # Config cache (critical untuk performance dengan Caddy)
  php artisan config:cache 2>/dev/null || true
  
  # Route cache (untuk faster routing dengan reverse proxy)
  php artisan route:cache 2>/dev/null || true
  
  # View cache (reduce file I/O)
  php artisan view:cache 2>/dev/null || true
  
  # Optimize autoloader
  if command -v composer >/dev/null; then
    composer dump-autoload --optimize --no-interaction 2>/dev/null || true
  fi
fi

# Setup health check endpoint untuk Caddy/load balancer
if [[ "$SIIMUT_HEALTH_CHECK" == "true" ]]; then
  log "Setting up health check endpoint"
  
  # Create simple health check file
  cat > public/health << 'EOF'
<?php
// Simple health check for load balancers
header('Content-Type: application/json');
header('Cache-Control: no-cache, no-store, must-revalidate');

$status = ['status' => 'ok', 'timestamp' => time()];

// Basic database check
try {
    if (file_exists(__DIR__ . '/../vendor/autoload.php')) {
        require_once __DIR__ . '/../vendor/autoload.php';
        
        if (class_exists('Illuminate\Foundation\Application')) {
            $app = require_once __DIR__ . '/../bootstrap/app.php';
            $app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();
            
            // Test database connection
            DB::connection()->getPdo();
            $status['database'] = 'connected';
        }
    }
} catch (Exception $e) {
    $status['database'] = 'error';
    $status['status'] = 'degraded';
    http_response_code(503);
}

echo json_encode($status);
EOF
  chmod 644 public/health || true
  log "Health check endpoint ready at /health"
fi

# Create Caddy-friendly index.php if missing
if [[ ! -f public/index.php ]] && [[ -f index.php ]]; then
  log "Moving index.php to public directory for Caddy"
  mv index.php public/ || true
fi

# Ensure storage link exists for Caddy static file serving
if [[ ! -e public/storage ]] && [[ -d storage/app/public ]]; then
  log "Creating storage link for Caddy static serving"
  php artisan storage:link 2>/dev/null || ln -sf ../storage/app/public public/storage || true
fi

# Final permission normalization untuk web server
chown -R www-data:www-data storage bootstrap/cache public 2>/dev/null || true
chmod -R ug+rw storage bootstrap/cache || true
chmod -R ugo+r public || true

# Validate Laravel installation
if [[ -f artisan ]] && [[ -f vendor/autoload.php ]]; then
  if php artisan --version >/dev/null 2>&1; then
    log "Laravel validation successful"
  else
    error "Laravel validation failed"
    exit 1
  fi
fi

log "✅ SIIMUT optimized for Caddy server"
log "📊 Starting PHP-FPM with Caddy optimization"

# Start background health monitoring jika diminta
if [[ "$SIIMUT_HEALTH_CHECK" == "true" ]]; then
  (
    while true; do
      sleep 30
      # Basic health monitoring
      if ! php -r "echo 'ok';" >/dev/null 2>&1; then
        log "WARNING: PHP health check failed"
      fi
    done
  ) &
fi

exec "$@"