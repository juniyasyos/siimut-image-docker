#!/bin/bash
set -e

# =========================
# Build & Push SIIMUT Image to Registry
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
REGISTRY="${REGISTRY:-juniyasyos}"  # Docker Hub username
IMAGE_NAME="${IMAGE_NAME:-${STACK_NAME:-siimut}-app}"
APP_DIR="${APP_DIR:-siimut}"

# Full image tag
IMAGE_TAG="${REGISTRY}/${IMAGE_NAME}:${VERSION}"

echo "======================================"
echo "🏗️  Building SIIMUT Production Image"
echo "======================================"
echo "Registry: ${REGISTRY}"
echo "Image: ${IMAGE_NAME}"
echo "Version: ${VERSION}"
echo "App Dir: ${APP_DIR}"
echo "Full Tag: ${IMAGE_TAG}"
echo "======================================"

# Build the image
echo ""
echo "📦 Building Docker image (no cache to ensure fresh source)..."
docker build \
  --no-cache \
  -f DockerNew/php/Dockerfile.siimut-registry \
  --build-arg APP_DIR="${APP_DIR}" \
  --build-arg APP_NAME="SIIMUT Application" \
  --build-arg APP_ENV=production \
  -t "${IMAGE_TAG}" \
  -t "${REGISTRY}/${IMAGE_NAME}:latest" \
  -t "${REGISTRY}/${IMAGE_NAME}:$(date +%Y%m%d-%H%M%S)" \
  .

if [ $? -eq 0 ]; then
  echo "✅ Build successful!"
else
  echo "❌ Build failed!"
  exit 1
fi

# Push to registry
echo ""
echo "🚀 Pushing to registry: ${REGISTRY}..."
docker push "${IMAGE_TAG}"
docker push "${REGISTRY}/${IMAGE_NAME}:latest"

if [ $? -eq 0 ]; then
  echo "✅ Push successful!"
  echo ""
  echo "======================================"
  echo "✨ Images pushed:"
  echo "   ${IMAGE_TAG}"
  echo "   ${REGISTRY}/${IMAGE_NAME}:latest"
  echo "======================================"
else
  echo "❌ Push failed!"
  exit 1
fi

echo ""
echo "💡 Deploy with:"
echo "   docker pull ${IMAGE_TAG}"
echo "   docker-compose -f docker-compose.siimut-registry.yml up -d"
echo ""
echo "💡 To build next version:"
echo "   1. Edit VERSION file (e.g., 2.0.1)"
echo "   2. Run: ./build-push-siimut.sh"
echo "   Or override: ./build-push-siimut.sh 2.1.0"
