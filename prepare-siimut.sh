#!/bin/bash
set -e

# =========================
# Prepare SIIMUT Site Folder and Git Repository
# =========================

# Load configuration from .env.siimut if exists
if [ -f "env/.env.siimut" ]; then
    source <(grep -E '^(APP_DIR)=' env/.env.siimut | sed 's/^/export /')
fi

APP_DIR="${APP_DIR:-siimut}"
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
    echo "⚠️  Repository not found in ${SITE_DIR}"
    echo "💡 To clone the repository, run:"
    echo "   git clone <SIIMUT_REPO_URL> ${SITE_DIR}"
    echo "   Example: git clone https://github.com/juniyasyos/siimut.git ${SITE_DIR}"
    echo ""
    echo "After cloning, run this script again to pull updates."
    exit 1
fi

echo ""
echo "✅ SIIMUT site folder prepared successfully!"
echo "💡 Next: Run ./build-siimut.sh to build the image"