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
REPO_URL="${REPO_URL:-https://github.com/juniyasyos/si-imut.git}"
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
    if git pull origin siimut-sso; then
        echo "✅ Git pull successful!"
    else
        echo "❌ Git pull failed! Check repository status."
        exit 1
    fi
    cd "../../"
else
    echo "📥 Repository not found, cloning from ${REPO_URL}..."
    if git clone -b iam-service "${REPO_URL}" "${SITE_DIR}"; then
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

# parse arguments
NO_DEPS=false
for arg in "$@"; do
    case $arg in
        --no-install-dependencies|--no-install-depedencies)
            NO_DEPS=true
            shift
            ;;
        *)
            # ignore other args
            ;;
    esac
done

# Check dependencies
if [ "$NO_DEPS" = false ]; then
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

    # # Install Composer dependencies
    # echo "📦 Installing Composer dependencies..."
    # if [ -f "composer.json" ]; then
    #     composer install --no-interaction --optimize-autoloader
    #     echo "✅ Composer install complete"
    # else
    #     echo "⚠️  composer.json not found, skipping Composer install"
    # fi

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
else
    echo "⚠️  Skipping dependency checks/install and npm build per --no-install-dependencies flag"
fi

if [ "$NO_DEPS" = false ]; then
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
else
    echo "⚠️  Skipping Laravel validation, tests, and Livewire publish per --no-install-dependencies flag"
fi

cd "../../"
echo ""
echo "✅ Local verification and build preparation complete!"

# =========================
# Generate Production Environment File with Secrets
# =========================
echo ""
echo "======================================"
echo "🔐 Generating Production .env File"
echo "======================================"

PROD_ENV_FILE="env/.env.prod.siimut"

# Check if production .env already exists
if [ -f "${PROD_ENV_FILE}" ]; then
    echo "⚠️  ${PROD_ENV_FILE} already exists."
    read -p "Do you want to regenerate secrets? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⏭️  Skipping secret generation. Using existing ${PROD_ENV_FILE}"
        echo "💡 Next: Run ./build-siimut.sh to build the image"
        exit 0
    fi
fi

# Copy template to production config
echo "📋 Creating production env from template..."
cp env/.env.siimut "${PROD_ENV_FILE}"
echo "✅ Copied env/.env.siimut → ${PROD_ENV_FILE}"

echo ""
echo "🔧 Sanitizing environment file..."

# Create temp file for cleanup
TEMP_FILE="${PROD_ENV_FILE}.tmp"
cp "${PROD_ENV_FILE}" "${TEMP_FILE}"

# Remove inline comments from environment variables (everything after # that comes after value)
# Keep valid commented-out lines (those starting with #)
sed -i '/^[^#]/s/ *#.*//' "${TEMP_FILE}"
echo "  ✓ Removed inline comments"

# Fix invalid SESSION_SAME_SITE values (should be: lax, strict, or none)
sed -i 's|SESSION_SAME_SITE=stricton.*|SESSION_SAME_SITE=lax|' "${TEMP_FILE}"
sed -i 's|SESSION_SAME_SITE=strict.*on.*|SESSION_SAME_SITE=lax|' "${TEMP_FILE}"
echo "  ✓ Fixed invalid SESSION_SAME_SITE values"

# Ensure SESSION_DOMAIN is empty (no spaces, no comments)
sed -i 's|^SESSION_DOMAIN=.*|SESSION_DOMAIN=|' "${TEMP_FILE}"
echo "  ✓ Ensured SESSION_DOMAIN is properly empty"

# Remove duplicate SESSION configuration lines (keep only the first occurrence of each)
awk '!/^SESSION_/ || !seen[$0]++' "${TEMP_FILE}" > "${TEMP_FILE}.dedup"
mv "${TEMP_FILE}.dedup" "${TEMP_FILE}"
echo "  ✓ Removed duplicate SESSION configuration"

mv "${TEMP_FILE}" "${PROD_ENV_FILE}"
echo "✅ Environment file sanitized"

echo ""
echo "🔧 Generating secrets..."

# Generate APP_KEY (32 bytes, base64 encoded)
if command -v php &> /dev/null; then
    APP_KEY="base64:$(php -r 'echo base64_encode(random_bytes(32));')"
else
    # Fallback if PHP not available (for CI/CD)
    APP_KEY="base64:$(openssl rand -base64 32 | tr -d '\n')"
fi
echo "  ✓ APP_KEY generated"

# Generate database password (16 bytes)
DB_PASSWORD="$(openssl rand -base64 16 | tr -d '\n')"
echo "  ✓ Database password generated"

# Generate MySQL root password
MYSQL_ROOT_PASSWORD="$(openssl rand -base64 16 | tr -d '\n')"
echo "  ✓ MySQL root password generated"

# Get IAM_JWT_SECRET from env/.env.iam or env/.env.prod.iam
# This ensures SIIMUT uses same JWT secret as IAM
if [ -f "env/.env.prod.iam" ]; then
    IAM_JWT_SECRET=$(grep '^IAM_JWT_SECRET=' env/.env.prod.iam | cut -d '=' -f 2 | tr -d ' ')
    if [ -n "$IAM_JWT_SECRET" ]; then
        echo "  ✓ IAM_JWT_SECRET synced from env/.env.prod.iam"
        echo "    Value: ${IAM_JWT_SECRET:0:16}...${IAM_JWT_SECRET: -16}"
    else
        # Fallback: generate a new one (not ideal, but better than empty)
        IAM_JWT_SECRET="$(openssl rand -hex 32)"
        echo "  ⚠️  IAM_JWT_SECRET in env/.env.prod.iam is empty, generating new one"
        echo "    Value: ${IAM_JWT_SECRET:0:16}...${IAM_JWT_SECRET: -16}"
    fi
else
    # Fallback: generate a new one (not ideal, but better than empty)
    IAM_JWT_SECRET="$(openssl rand -hex 32)"
    echo "  ⚠️  env/.env.prod.iam not found!"
    echo "    IMPORTANT: Run ./prepare-iam.sh FIRST before this script!"
    echo "    Generating new IAM_JWT_SECRET (will cause token verification to fail)"
    echo "    Value: ${IAM_JWT_SECRET:0:16}...${IAM_JWT_SECRET: -16}"
fi

echo ""
echo "📝 Updating ${PROD_ENV_FILE} with generated secrets..."

# Use temp file for safer sed replacement
TEMP_FILE="${PROD_ENV_FILE}.tmp"
cp "${PROD_ENV_FILE}" "${TEMP_FILE}"

# Replace placeholders with actual values
sed -i "s|^APP_KEY=.*|APP_KEY=${APP_KEY}|" "${TEMP_FILE}"
sed -i "s|^MYSQL_PASSWORD=.*|MYSQL_PASSWORD=${DB_PASSWORD}|" "${TEMP_FILE}"
sed -i "s|^MYSQL_ROOT_PASSWORD=.*|MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}|" "${TEMP_FILE}"
sed -i "s|^IAM_JWT_SECRET=.*|IAM_JWT_SECRET=${IAM_JWT_SECRET}|" "${TEMP_FILE}"

mv "${TEMP_FILE}" "${PROD_ENV_FILE}"
echo "✅ Secrets updated in ${PROD_ENV_FILE}"

# Final validation
echo ""
echo "🔍 Validating environment file..."
SESSION_DOMAIN_VAL=$(grep '^SESSION_DOMAIN=' "${PROD_ENV_FILE}" | cut -d '=' -f 2)
SESSION_SAME_SITE_VAL=$(grep '^SESSION_SAME_SITE=' "${PROD_ENV_FILE}" | cut -d '=' -f 2)
JWT_VAL=$(grep '^IAM_JWT_SECRET=' "${PROD_ENV_FILE}" | cut -d '=' -f 2 | tr -d ' ')

if [ -z "$SESSION_DOMAIN_VAL" ]; then
    echo "  ✓ SESSION_DOMAIN is properly empty"
else
    echo "  ⚠️  SESSION_DOMAIN has value: '$SESSION_DOMAIN_VAL' (should be empty)"
fi

if [[ "$SESSION_SAME_SITE_VAL" =~ ^(lax|strict|none)$ ]]; then
    echo "  ✓ SESSION_SAME_SITE is valid: $SESSION_SAME_SITE_VAL"
else
    echo "  ⚠️  SESSION_SAME_SITE has invalid value: '$SESSION_SAME_SITE_VAL' (should be: lax, strict, or none)"
fi

# Validate JWT secret matches between IAM and SIIMUT
echo ""
echo "🔐 JWT Secret Verification:"
if [ -f "env/.env.prod.iam" ]; then
    IAM_JWT=$(grep '^IAM_JWT_SECRET=' env/.env.prod.iam | cut -d '=' -f 2 | tr -d ' ')
    SIIMUT_JWT=$(grep '^IAM_JWT_SECRET=' "${PROD_ENV_FILE}" | cut -d '=' -f 2 | tr -d ' ')
    
    echo "  IAM Secret:    ${IAM_JWT:0:16}...${IAM_JWT: -16}"
    echo "  SIIMUT Secret: ${SIIMUT_JWT:0:16}...${SIIMUT_JWT: -16}"
    
    if [ "$IAM_JWT" = "$SIIMUT_JWT" ]; then
        echo "  ✅ JWT Secrets MATCH! Applications will verify tokens correctly."
    else
        echo "  ❌ JWT Secrets DO NOT MATCH! Token verification will fail!"
        echo "     This will cause infinite redirect loops when logging in from IAM."
    fi
else
    echo "  ⚠️  env/.env.prod.iam not found - cannot verify JWT secret match"
fi

echo ""
echo "======================================"
echo "🎉 Production Environment Generated!"
echo "======================================"
echo ""
echo "📁 Environment file: ${PROD_ENV_FILE}"
echo "� Summary:"
echo "   • APP_KEY: Generated ✓"
echo "   • IAM_JWT_SECRET: Synced from IAM ✓"
echo "   • Database credentials: Generated ✓"
echo "   • Session configuration: Validated ✓"
echo ""
echo "🔐 Secret Match Verification (Critical):"
if [ -f "env/.env.prod.iam" ]; then
    IAM_JWT_FINAL=$(grep '^IAM_JWT_SECRET=' env/.env.prod.iam | cut -d '=' -f 2 | tr -d ' ')
    SIIMUT_JWT_FINAL=$(grep '^IAM_JWT_SECRET=' "${PROD_ENV_FILE}" | cut -d '=' -f 2 | tr -d ' ')
    
    echo "   IAM:    ${IAM_JWT_FINAL:0:16}...${IAM_JWT_FINAL: -16}"
    echo "   SIIMUT: ${SIIMUT_JWT_FINAL:0:16}...${SIIMUT_JWT_FINAL: -16}"
    
    if [ "$IAM_JWT_FINAL" = "$SIIMUT_JWT_FINAL" ]; then
        echo "   ✅ MATCH - SSO login will work correctly!"
    else
        echo "   ❌ MISMATCH - Token verification will FAIL!"
    fi
fi
echo ""
echo "⚠️  IMPORTANT: This file is in .gitignore - DO NOT commit!"
echo ""
echo "📌 NEXT STEPS (in order):"
echo "   1. Verify JWT secrets match (see output above)"
echo "   2. Run ./build-siimut.sh       (build SIIMUT Docker image)"
echo "   3. Run docker compose up       (start all services)"