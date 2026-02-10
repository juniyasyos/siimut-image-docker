#!/bin/bash
set -e

# =========================
# Build SIIMUT Image Locally (No Push)
# =========================

# Load configuration from .env.siimut if exists
if [ -f "env/.env.siimut" ]; then
    source <(grep -E '^(STACK_NAME|APP_DIR)=' env/.env.siimut | sed 's/^/export /')
fi

# Read version from VERSION file or use parameter
if [ -f "VERSION" ]; then
    DEFAULT_VERSION=$(cat VERSION)
else
    DEFAULT_VERSION="latest"
fi

# Allow version override via parameter
if [ -n "$1" ]; then
    VERSION="$1"
else
    VERSION="${VERSION:-$DEFAULT_VERSION}"
fi

# Configuration
IMAGE_NAME="${IMAGE_NAME:-${STACK_NAME:-siimut}-app}"
APP_DIR="${APP_DIR:-siimut}"

# Pull latest code from Git
echo ""
echo "🔄 Pulling latest code from Git repository..."
cd "site/${APP_DIR}"
if git pull origin feat-daily-report; then
    echo "✅ Git pull successful!"
else
    echo "❌ Git pull failed! Continuing with current code..."
fi
cd "../../"

# Full image tag (local only)
IMAGE_TAG="${IMAGE_NAME}:${VERSION}"

echo "======================================"
echo "🏗️  Building SIIMUT Production Image (Local)"
echo "======================================"
echo "Image: ${IMAGE_NAME}"
echo "Version: ${VERSION}"
echo "App Dir: ${APP_DIR}"
echo "Local Tag: ${IMAGE_TAG}"
echo "======================================"

# Pre-build validation
echo ""
echo "🔍 Pre-build validation..."
if [ ! -d "site/${APP_DIR}" ]; then
  echo "❌ Error: Directory site/${APP_DIR} does not exist!"
  exit 1
fi

# Show recent changes in source directory
echo "📝 Recent changes in site/${APP_DIR}:"
find "site/${APP_DIR}" -type f -mtime -1 -ls 2>/dev/null | head -5 || echo "  No recent changes (within 24h)"

# Build timestamp for cache invalidation
BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BUILD_DATE_TAG=$(date +%Y%m%d-%H%M%S)

# Build the image
echo ""
echo "📦 Building Docker image (no cache to ensure fresh source)..."
echo "🕒 Build timestamp: ${BUILD_TIMESTAMP}"
docker build \
  --no-cache \
  -f DockerNew/php/Dockerfile.siimut-registry \
  --build-arg APP_DIR="${APP_DIR}" \
  --build-arg APP_NAME="SIIMUT Application" \
  --build-arg APP_ENV=production \
  --build-arg BUILD_TIMESTAMP="${BUILD_TIMESTAMP}" \
  -t "${IMAGE_TAG}" \
  -t "${IMAGE_NAME}:latest" \
  -t "${IMAGE_NAME}:${BUILD_DATE_TAG}" \
  .

if [ $? -eq 0 ]; then
  echo "✅ Build successful!"
  
  # Post-build validation - check if source files are in the image
  echo ""
  echo "🔍 Post-build validation..."
  echo "📋 Checking if Laravel app files are in the image..."
  
  # Create a temporary container to inspect contents
  TEMP_CONTAINER=$(docker create "${IMAGE_TAG}")
  
  # Check for key Laravel files
  docker cp "${TEMP_CONTAINER}:/var/www/siimut/artisan" "/tmp/artisan.check" 2>/dev/null && echo "✅ artisan found" || echo "❌ artisan missing"
  docker cp "${TEMP_CONTAINER}:/var/www/siimut/composer.json" "/tmp/composer.check" 2>/dev/null && echo "✅ composer.json found" || echo "❌ composer.json missing"
  docker cp "${TEMP_CONTAINER}:/var/www/siimut/app" "/tmp/app.check" 2>/dev/null && echo "✅ app/ directory found" || echo "❌ app/ directory missing"
  
  # Check file timestamps in container vs source
  if docker cp "${TEMP_CONTAINER}:/var/www/siimut/config/app.php" "/tmp/app-config.check" 2>/dev/null; then
    SOURCE_TIME=$(stat -c %Y "site/${APP_DIR}/config/app.php" 2>/dev/null || echo "0")
    CONTAINER_TIME=$(stat -c %Y "/tmp/app-config.check" 2>/dev/null || echo "0")
    if [ "$CONTAINER_TIME" -ge "$SOURCE_TIME" ]; then
      echo "✅ app.php timestamp looks current"
    else
      echo "⚠️  app.php timestamp might be stale"
    fi
  fi
  
  # Cleanup
  docker rm "${TEMP_CONTAINER}" >/dev/null 2>&1
  rm -f /tmp/*.check 2>/dev/null
  
else
  echo "❌ Build failed!"
  exit 1
fi

echo ""
echo "======================================"
echo "✨ Local images built:"
echo "   ${IMAGE_TAG}"
echo "   ${IMAGE_NAME}:latest"
echo "   ${IMAGE_NAME}:${BUILD_DATE_TAG}"
echo "======================================"

echo ""
echo "💡 Deploy with:"
echo "   docker-compose -f docker-compose-multi-apps.yml up --build -d"
echo ""
echo "💡 To build next version:"
echo "   1. Edit VERSION file (e.g., 2.0.1)"
echo "   2. Run: ./build-siimut.sh"
echo "   Or override: ./build-siimut.sh 2.1.0"