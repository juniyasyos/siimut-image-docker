#!/bin/bash
set -e

# =========================
# Build and Push SIIMUT Image for Development/Testing
# =========================

# Load configuration from .env and env/.env.siimut (if any)
# REGISTRY_URL biasanya di .env, variabel lainnya dapat berada di env/.env.siimut
if [ -f "env/.env.siimut" ]; then
    # ekspor semua key=value (abaikan komentar)
    export $(grep -v '^#' env/.env.siimut | xargs 2>/dev/null) || true
fi
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs 2>/dev/null) || true
fi
# Registry configuration
REGISTRY_URL="${REGISTRY_URL:-localhost:5000}"  # Change this to your registry
IMAGE_NAME="siimut"
TAG="dev-v3"

# Registry configuration
REGISTRY_URL="${REGISTRY_URL:-localhost:5000}"  # Change this to your registry
IMAGE_NAME="siimut"
TAG="dev-v3"

# Full image paths
LOCAL_IMAGE="${IMAGE_NAME}:${TAG}"
REGISTRY_IMAGE="${REGISTRY_URL}/${IMAGE_NAME}:${TAG}"

echo "======================================"
echo "🏗️  Building SIIMUT Dev Image"
echo "======================================"
echo "Local Image:    ${LOCAL_IMAGE}"
echo "Registry Image: ${REGISTRY_IMAGE}"
echo "======================================"
echo ""

# Pre-build validation
echo "🔍 Pre-build validation..."
if [ ! -d "site/siimut" ]; then
    echo "❌ site/siimut directory not found!"
    exit 1
fi

# Show recent changes to verify source is up to date
echo "📝 Recent changes in site/siimut:"
find site/siimut/public/build -type f -name "*.js" -o -name "*.css" -o -name "manifest.json" 2>/dev/null | head -5 || echo "  (no recent build artifacts found)"
echo ""

# Buat daftar build-arg berdasarkan variabel lingkungan yang tersedia
BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "📦 Building Docker image (no cache to ensure fresh source)..."
echo "🕒 Build timestamp: ${BUILD_TIMESTAMP}"
echo ""

# array nama variabel yang ingin kita teruskan ke build
_vars=(APP_DIR APP_NAME APP_ENV DB_HOST DB_USERNAME DB_PASSWORD DB_DATABASE \
       AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_BUCKET AWS_URL AWS_ENDPOINT)
BUILD_ARGS=()
for v in "${_vars[@]}"; do
    if [ -n "${!v}" ]; then
        BUILD_ARGS+=(--build-arg "$v=${!v}")
    fi
done
# tambahkan TIMESTAMP terlepas dari apapun
BUILD_ARGS+=(--build-arg "BUILD_TIMESTAMP=${BUILD_TIMESTAMP}")

# jalankan build

docker build \
  --progress=plain \
  "${BUILD_ARGS[@]}" \
  -f DockerNew/php/Dockerfile.siimut-registry \
  -t "${LOCAL_IMAGE}" \
  -t "${REGISTRY_IMAGE}" \
  .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    
    # Show image details
    echo "📊 Image Details:"
    docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    echo ""
    
    # Push to registry
    echo "======================================"
    echo "📤 Pushing to Registry"
    echo "======================================"
    echo "Target: ${REGISTRY_IMAGE}"
    echo ""
    
    docker push "${REGISTRY_IMAGE}"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Push successful!"
        echo ""
        echo "======================================"
        echo "🎉 Image Ready for Deployment"
        echo "======================================"
        echo "Image: ${REGISTRY_IMAGE}"
        echo ""
        echo "To pull on server:"
        echo "  docker pull ${REGISTRY_IMAGE}"
        echo ""
        echo "To run with compose:"
        echo "  docker compose -f docker-compose-multi-apps.yml up -d"
        echo ""
    else
        echo ""
        echo "❌ Push failed!"
        echo "Check registry connection and credentials."
        exit 1
    fi
else
    echo ""
    echo "❌ Build failed!"
    exit 1
fi
