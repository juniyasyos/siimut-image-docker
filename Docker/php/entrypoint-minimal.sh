#!/usr/bin/env bash
set -euo pipefail

# entrypoint-minimal.sh — Ultra-minimal entrypoint untuk testing/debugging
#
# Hanya melakukan hal-hal paling esensial:
# - Set working directory
# - Basic permissions
# - Generate APP_KEY jika diperlukan
# - Start process

APP_DIR="/var/www/html"
SIIMUT_DIR="$APP_DIR/si-imut"

echo "[$(date +'%H:%M:%S')] 🚀 SIIMUT Minimal Bootstrap"

# Find Laravel app
if [[ -d "$SIIMUT_DIR" ]] && [[ -f "$SIIMUT_DIR/artisan" ]]; then
  cd "$SIIMUT_DIR"
  echo "[$(date +'%H:%M:%S')] Using: $SIIMUT_DIR"
elif [[ -d "$APP_DIR" ]] && [[ -f "$APP_DIR/artisan" ]]; then
  cd "$APP_DIR"
  echo "[$(date +'%H:%M:%S')] Using: $APP_DIR"
else
  echo "[$(date +'%H:%M:%S')] ❌ No Laravel app found"
  exec "$@"
fi

# Minimal directories
mkdir -p storage/{logs,framework/{sessions,views,cache}} bootstrap/cache 2>/dev/null || true

# Minimal permissions
chmod -R ug+rw storage bootstrap/cache 2>/dev/null || true

# Generate APP_KEY only if absolutely necessary
if [[ -f .env ]] && ! grep -q "APP_KEY=" .env; then
  KEY=$(php -r 'echo "base64:".base64_encode(random_bytes(32));')
  echo "APP_KEY=${KEY}" >> .env
  echo "[$(date +'%H:%M:%S')] 🔑 Generated APP_KEY"
fi

echo "[$(date +'%H:%M:%S')] ✅ Ready"
exec "$@"