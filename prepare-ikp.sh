#!/bin/bash
set -e

# =========================
# Prepare IKP Site Folder and Git Repository
# =========================

# Load configuration from env/.env.ikp if exists (JUST LIKE prepare-siimut.sh & prepare-iam.sh)
if [ -f "env/.env.ikp" ]; then
    source <(grep -E '^(APP_DIR|APPP_KEY|REPO_URL|BRANCH|DB_DATABASE|DB_USER|DB_PASSWORD)=' env/.env.ikp | sed 's/^/export /')
fi

APP_DIR="${APP_DIR:-ikp}"
REPO_URL="${REPO_URL:-https://github.com/juniyasyos/ikp.git}"
BRANCH="${BRANCH:-iam-app}"
SITE_DIR="site/${APP_DIR}"

# Database variables (untuk reference)
DB_DATABASE="${DB_DATABASE:-ikp_db}"
DB_USER="${DB_USER:-ikp_user}"
DB_PASSWORD="${DB_PASSWORD:-ikp-password}"

echo "======================================"
echo "📁 Preparing IKP Site Folder"
echo "======================================"
echo "App Dir: ${APP_DIR}"
echo "Site Dir: ${SITE_DIR}"
echo "Repository: ${REPO_URL}"
echo "Branch: ${BRANCH}"
echo "Database: ${DB_DATABASE}"
echo "DB User: ${DB_USER}"
echo "======================================"

# Create site directory if not exists
if [ ! -d "site" ]; then
    echo "📁 Creating site directory..."
    mkdir -p site
fi

# Check if repository exists
if [ -d "${SITE_DIR}/.git" ]; then
    echo "🔄 Repository exists, pulling latest code from branch '${BRANCH}'..."
    cd "${SITE_DIR}"
    
    # Ensure we're on the correct branch
    git fetch origin
    if ! git rev-parse --verify origin/${BRANCH} > /dev/null 2>&1; then
        echo "⚠️  Branch '${BRANCH}' not found on origin. Using default branch..."
        if git pull origin; then
            echo "✅ Git pull successful!"
        else
            echo "❌ Git pull failed! Check repository status."
            exit 1
        fi
    else
        if git checkout ${BRANCH} && git pull origin ${BRANCH}; then
            echo "✅ Git pull successful on branch '${BRANCH}'!"
        else
            echo "❌ Git pull failed! Check repository status."
            exit 1
        fi
    fi
    cd "../../"
else
    echo "📥 Repository not found, cloning from ${REPO_URL}..."
    if git clone -b "${BRANCH}" "${REPO_URL}" "${SITE_DIR}" 2>/dev/null || git clone "${REPO_URL}" "${SITE_DIR}"; then
        echo "✅ Git clone successful!"
    else
        echo "❌ Git clone failed! Check URL and network."
        exit 1
    fi
fi
x
echo ""
echo "✅ IKP site folder prepared successfully!"

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

echo ""
echo "======================================"
echo "📋 IKP Setup Complete!"
echo "======================================"
echo ""
echo "📌 Database Configuration (from env/.env.ikp):"
echo "   Database: ${DB_DATABASE}"
echo "   User: ${DB_USER}"
echo "   Password: ${DB_PASSWORD}"
echo "   Host: db (inside Docker)"
echo ""
echo "Next steps:"
echo ""
echo "1️⃣  Configure .env file:"
echo "   nano ${SITE_DIR}/.env"
echo "   Make sure DB_DATABASE and DB_USERNAME match:"
echo "   - DB_DATABASE=${DB_DATABASE}"
echo "   - DB_USERNAME=${DB_USER}"
echo "   - DB_PASSWORD=${DB_PASSWORD}"
echo "   - DB_HOST=db"
echo ""
echo "2️⃣  (Optional) Install local dependencies:"
echo "   cd ${SITE_DIR}"
echo "   composer install"
echo "   npm install"
echo "   cd ../../"
echo ""
echo "3️⃣  Build Docker image and start services:"
echo "   docker compose -f docker-compose.base.yml -f docker-compose-multi-apps.yml build"
echo "   docker compose -f docker-compose.base.yml -f docker-compose-multi-apps.yml up -d"
echo ""
echo "4️⃣  Run migrations:"
echo "   docker compose -f docker-compose.base.yml -f docker-compose-multi-apps.yml exec app-ikp php artisan migrate"
echo ""
echo "5️⃣  Access IKP:"
echo "   http://localhost:8082"
echo ""
echo "📚 Reference:"
echo "   Database Credentials: cat ../DATABASE-CREDENTIALS.md"
echo "   IKP Configuration: cat env/.env.ikp"
echo "======================================"
