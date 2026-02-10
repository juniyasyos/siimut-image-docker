#!/bin/bash
set -e

# =========================
# Prepare IAM Site Folder and Git Repository
# =========================

# Load configuration from .env.iam if exists
if [ -f "env/.env.iam" ]; then
    source <(grep -E '^(APP_DIR)=' env/.env.iam | sed 's/^/export /')
fi

APP_DIR="${APP_DIR:-iam-server}"
SITE_DIR="site/${APP_DIR}"

echo "======================================"
echo "📁 Preparing IAM Site Folder"
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
    if git pull origin dev; then
        echo "✅ Git pull successful!"
    else
        echo "❌ Git pull failed! Check repository status."
        exit 1
    fi
    cd "../../"
else
    echo "⚠️  Repository not found in ${SITE_DIR}"
    echo "💡 To clone the repository, run:"
    echo "   git clone <IAM_REPO_URL> ${SITE_DIR}"
    echo "   Example: git clone https://github.com/juniyasyos/laravel-iam.git ${SITE_DIR}"
    echo ""
    echo "After cloning, run this script again to pull updates."
    exit 1
fi

echo ""
echo "✅ IAM site folder prepared successfully!"
echo "💡 Next: Run ./build-iam.sh to build the image"