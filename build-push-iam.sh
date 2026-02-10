#!/bin/bash
set -e

# =========================
# Build & Push IAM Image to Registry
# =========================

# Load configuration from .env.iam if exists
if [ -f "env/.env.iam" ]; then
    source <(grep -E '^(STACK_NAME|APP_DIR)=' env/.env.iam | sed 's/^/export /')
fi

# Configuration
REGISTRY="${REGISTRY:-juniyasyos}"  # Docker Hub username
IMAGE_NAME="${IMAGE_NAME:-${STACK_NAME:-iam}-server}"
VERSION="${VERSION:-latest}"
APP_DIR="${APP_DIR:-iam-server}"

# Pull latest code from Git
echo ""
echo "🔄 Pulling latest code from Git repository..."
cd "site/${APP_DIR}"
if git pull origin main; then
    echo "✅ Git pull successful!"
else
    echo "❌ Git pull failed! Continuing with current code..."
fi
cd "../../"

# Full image tag
IMAGE_TAG="${REGISTRY}/${IMAGE_NAME}:${VERSION}"

echo "======================================"
echo "🏗️  Building IAM Production Image"
echo "======================================"
echo "Registry: ${REGISTRY}"
echo "Image: ${IMAGE_NAME}"
echo "Version: ${VERSION}"
echo "App Dir: ${APP_DIR}"
echo "Full Tag: ${IMAGE_TAG}"
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

if [ $? -eq 0 ]; then
  echo "✅ Push successful!"
  echo ""
  echo "======================================"
  echo "✨ Image is ready to deploy:"
  echo "   ${IMAGE_TAG}"
  echo "======================================"
else
  echo "❌ Push failed!"
  exit 1
fi

# Optional: Also push timestamped version
TIMESTAMP_TAG="${REGISTRY}/${IMAGE_NAME}:$(date +%Y%m%d-%H%M%S)"
echo ""
echo "🔖 Also pushed as: ${TIMESTAMP_TAG}"

echo ""
echo "💡 Deploy with:"
echo "   docker pull ${IMAGE_TAG}"
echo "   docker-compose -f docker-compose.registry.yml up -d"
