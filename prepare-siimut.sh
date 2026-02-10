#!/bin/bash
set -e

# =========================
# Prepare SIIMUT Site Folder and Git Repository
# =========================

# Load configuration from .env.siimut if exists
if [ -f "env/.env.siimut" ]; then
    source <(grep -E '^(APP_DIR|REPO_URL)=' env/.env.siimut | sed 's/^/export /')
fi

APP_DIR="${APP_DIR:-siimut}"
REPO_URL="${REPO_URL:-https://github.com/juniyasyos/siimut.git}"
SITE_DIR="site/${APP_DIR}"

echo "======================================"
echo "📁 Preparing SIIMUT Site Folder"
echo "======================================"
echo "App Dir: ${APP_DIR}"
echo "Site Dir: ${SITE_DIR}"
echo "======================================"

# Create site directory if not exists
if [ ! -d "site" ]; then
    echo "📁 Creating site directory..."
    mkdir -p site
fi

# Check if repository exists
if [ -d "${SITE_DIR}/.git" ]; then
    echo "🔄 Repository exists, pulling latest code..."
    cd "${SITE_DIR}"
    if git pull origin feat-daily-report; then
        echo "✅ Git pull successful!"
    else
        echo "❌ Git pull failed! Check repository status."
        exit 1
    fi
    cd "../../"
else
    echo "📥 Repository not found, cloning from ${REPO_URL}..."
    if git clone -b feat-daily-report "${REPO_URL}" "${SITE_DIR}"; then
        echo "✅ Git clone successful!"
    else
        echo "❌ Git clone failed! Check URL and network."
        exit 1
    fi
fi

echo ""
echo "✅ SIIMUT site folder prepared successfully!"

# Prepare environment file
if [ ! -f "${SITE_DIR}/.env" ]; then
    if [ -f "${SITE_DIR}/.env.example" ]; then
        echo "📋 Copying .env.example to .env..."
        cp "${SITE_DIR}/.env.example" "${SITE_DIR}/.env"
        echo "✅ .env file created. Please configure it as needed."
    else
        echo "⚠️  .env.example not found. Please create .env manually."
    fi
else
    echo "✅ .env file already exists."
fi

# Build frontend assets
echo ""
echo "📦 Building frontend assets..."
cd "${SITE_DIR}"

if [ -f package.json ]; then
    echo "  📋 Running npm install..."
    if npm install; then
        echo "✅ npm install successful"
    else
        echo "❌ npm install failed!"
        exit 1
    fi
    
    echo "  🔨 Running npm run build..."
    if npm run build; then
        echo "✅ npm run build successful"
    else
        echo "❌ npm run build failed!"
        exit 1
    fi
    
    echo "🔍 Build artifacts:"
    [ -d build ] && ls -la build/ | head -5 || echo "  build/ not found"
    [ -d dist ] && ls -la dist/ | head -5 || echo "  dist/ not found"
else
    echo "⚠️  package.json not found, skipping npm build"
fi

cd "../../"

echo ""
echo "✅ SIIMUT fully prepared with build assets!"
echo "💡 Next: Run 'docker-compose -f docker-compose-multi-apps.yml build --no-cache && docker-compose -f docker-compose-multi-apps.yml up -d'"