#!/bin/bash
set -e

# =========================
# Prepare IAM Site Folder and Git Repository
# =========================

# Load configuration from .env.iam if exists
if [ -f "env/.env.iam" ]; then
    source <(grep -E '^(APP_DIR|REPO_URL)=' env/.env.iam | sed 's/^/export /')
fi

APP_DIR="${APP_DIR:-iam-server}"
REPO_URL="${REPO_URL:-https://github.com/juniyasyos/laravel-iam.git}"
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
    echo "📥 Repository not found, cloning from ${REPO_URL}..."
    if git clone -b dev "${REPO_URL}" "${SITE_DIR}"; then
        echo "✅ Git clone successful!"
    else
        echo "❌ Git clone failed! Check URL and network."
        exit 1
    fi
fi

echo ""
echo "✅ IAM site folder prepared successfully!"

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

echo "💡 Next: Run ./build-iam.sh to build the image"