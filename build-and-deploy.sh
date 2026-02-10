#!/bin/bash
set -e

# =========================
# Complete Build and Deploy Script
# 1. Prepare repos (git clone/pull)
# 2. Build images
# 3. Deploy containers
# =========================

echo "======================================"
echo "🚀 Complete Build & Deploy for Multi-Apps"
echo "======================================"

# Step 1: Prepare SIIMUT repo
echo ""
echo "📁 [1/5] Preparing SIIMUT repository..."
./prepare-siimut.sh || { echo "❌ prepare-siimut.sh failed"; exit 1; }

# Step 2: Prepare IAM repo
echo ""
echo "📁 [2/5] Preparing IAM repository..."
./prepare-iam.sh || { echo "❌ prepare-iam.sh failed"; exit 1; }

# Step 3: Verify repos exist
echo ""
echo "✅ [3/5] Verifying repositories..."
[ -d "site/siimut" ] && echo "✅ site/siimut found" || { echo "❌ site/siimut not found"; exit 1; }
[ -d "site/iam-server" ] && echo "✅ site/iam-server found" || { echo "❌ site/iam-server not found"; exit 1; }
[ -f "site/siimut/package.json" ] && echo "✅ siimut/package.json found" || echo "⚠️  siimut/package.json not found (npm build will be skipped)"
[ -f "site/iam-server/package.json" ] && echo "✅ iam-server/package.json found" || echo "⚠️  iam-server/package.json not found (npm build will be skipped)"

# Step 4: Build images with --no-cache
echo ""
echo "🐳 [4/5] Building Docker images (this may take a few minutes)..."
docker compose -f docker-compose-multi-apps.yml build --no-cache || { echo "❌ Docker build failed"; exit 1; }

# Step 5: Deploy containers
echo ""
echo "🚀 [5/5] Deploying containers..."
docker compose -f docker-compose-multi-apps.yml up -d || { echo "❌ Docker compose up failed"; exit 1; }

echo ""
echo "======================================"
echo "✅ Complete Build & Deploy Success!"
echo "======================================"
echo ""
echo "📍 Access applications at:"
echo "   SIIMUT: http://192.168.1.9:8000"
echo "   IAM:    http://192.168.1.9:8100"
echo ""
echo "💡 View logs:"
echo "   docker logs siimut-app"
echo "   docker logs iam-app"
echo "   docker logs multi-web"
echo ""
echo "🛑 Stop all:"
echo "   docker-compose -f docker-compose-multi-apps.yml down"
