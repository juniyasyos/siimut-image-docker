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

# =========================
# Local Verification and Build Preparation
# =========================
echo ""
echo "🔍 Starting local verification and build preparation..."
cd "${SITE_DIR}"

# Check dependencies
echo "🔧 Checking dependencies..."
if ! command -v php &> /dev/null; then
    echo "❌ PHP not found. Please install PHP 8.1+."
    exit 1
fi
if ! command -v composer &> /dev/null; then
    echo "❌ Composer not found. Please install Composer."
    exit 1
fi
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js 16+."
    exit 1
fi
if ! command -v npm &> /dev/null; then
    echo "❌ npm not found. Please install npm."
    exit 1
fi
echo "✅ Dependencies OK"

# Install Composer dependencies
echo "📦 Installing Composer dependencies..."
if [ -f "composer.json" ]; then
    composer install --no-interaction --optimize-autoloader
    echo "✅ Composer install complete"
else
    echo "⚠️  composer.json not found, skipping Composer install"
fi

# Install npm dependencies and build frontend
echo "📦 Installing npm dependencies..."
if [ -f "package.json" ]; then
    npm install
    echo "🔨 Building frontend assets..."
    npm run build
    echo "✅ Frontend build complete"
else
    echo "⚠️  package.json not found, skipping npm build"
fi

# Validate Laravel setup
echo "🔍 Validating Laravel setup..."
if [ -f "artisan" ]; then
    php artisan --version
    echo "✅ Laravel OK"
else
    echo "❌ artisan not found. Not a valid Laravel app."
    exit 1
fi

# Test basic functionality (optional artisan commands)
echo "🧪 Running basic tests..."
php artisan config:cache --quiet || echo "⚠️ config:cache failed (continuing)"
php artisan route:cache --quiet || echo "⚠️ route:cache failed (continuing)"
php artisan view:cache --quiet || echo "⚠️ view:cache failed (continuing)"

# Publish Livewire assets (IMPORTANT for form submissions)
echo "📦 Publishing Livewire assets..."
php artisan livewire:publish --assets --quiet || echo "⚠️ livewire:publish failed (continuing)"

echo "✅ Livewire assets published to public/vendor/livewire/"

cd "../../"
echo ""
echo "✅ Local verification and build preparation complete!"
echo "💡 Next: Run ./build-siimut.sh to build the Docker image"