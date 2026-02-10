#!/bin/bash
set -e

# =========================
# Build IAM Image Locally (No Push)
# =========================

# Load configuration from .env.iam if exists
if [ -f "env/.env.iam" ]; then
    source <(grep -E '^(STACK_NAME|APP_DIR)=' env/.env.iam | sed 's/^/export /')
fi

# Configuration
IMAGE_NAME="${IMAGE_NAME:-${STACK_NAME:-iam}-server}"
VERSION="${VERSION:-latest}"
APP_DIR="${APP_DIR:-iam-server}"

# Pull latest code from Git
echo ""
echo "🔄 Pulling latest code from Git repository..."
cd "site/${APP_DIR}"
if git pull origin dev; then
    echo "✅ Git pull successful!"
else
    echo "❌ Git pull failed! Continuing with current code..."
fi
cd "../../"

# Full image tag (local only)
IMAGE_TAG="${IMAGE_NAME}:${VERSION}"

echo "======================================"
echo "🏗️  Building IAM Production Image (Local)"
echo "======================================"
echo "Image: ${IMAGE_NAME}"
echo "Version: ${VERSION}"
echo "App Dir: ${APP_DIR}"
echo "Local Tag: ${IMAGE_TAG}"
echo "======================================"

# Build the image
echo ""
echo "📦 Building Docker image..."
docker build \
  -f DockerNew/php/Dockerfile.iam-registry \
  --build-arg APP_DIR="${APP_DIR}" \
  --build-arg APP_NAME="IAM Server" \
  --build-arg APP_ENV=production \
  -t "${IMAGE_TAG}" \
  -t "${IMAGE_NAME}:$(date +%Y%m%d-%H%M%S)" \
  .

if [ $? -eq 0 ]; then
  echo "✅ Build successful!"
else
  echo "❌ Build failed!"
  exit 1
fi

echo ""
echo "======================================"
echo "✨ Local image built:"
echo "   ${IMAGE_TAG}"
echo "======================================"

echo ""
echo "💡 Deploy with:"
echo "   docker-compose -f docker-compose-multi-apps.yml up --build -d"