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
    if git pull origin main; then
        echo "✅ Git pull successful!"
    else
        echo "❌ Git pull failed! Check repository status."
        exit 1
    fi
    cd "../../"
else
    echo "📥 Repository not found, cloning from ${REPO_URL}..."
    if git clone -b main "${REPO_URL}" "${SITE_DIR}"; then
        echo "✅ Git clone successful!"
    else
        echo "❌ Git clone failed! Check URL and network."
        exit 1
    fi
fi

echo ""
echo "✅ IAM site folder prepared successfully!"

# =========================
# Generate Production Environment File with Secrets
# =========================
echo ""
echo "======================================"
echo "🔐 Generating Production .env File"
echo "======================================"

PROD_ENV_FILE="env/.env.prod.iam"

# Check if production .env already exists
if [ -f "${PROD_ENV_FILE}" ]; then
    echo "⚠️  ${PROD_ENV_FILE} already exists."
    read -p "Do you want to regenerate secrets? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⏭️  Skipping secret generation. Using existing ${PROD_ENV_FILE}"
        echo "💡 Next: Run ./build-iam.sh to build the image"
        exit 0
    fi
fi

# Copy template to production config
echo "📋 Creating production env from template..."
cp env/.env.iam "${PROD_ENV_FILE}"
echo "✅ Copied env/.env.iam → ${PROD_ENV_FILE}"

echo ""
echo "🔧 Sanitizing environment file..."

# Create temp file for cleanup
TEMP_FILE="${PROD_ENV_FILE}.tmp"
cp "${PROD_ENV_FILE}" "${TEMP_FILE}"

# Remove inline comments from environment variables (everything after # that comes after value)
# Keep valid commented-out lines (those starting with #)
sed -i '/^[^#]/s/ *#.*//' "${TEMP_FILE}"
echo "  ✓ Removed inline comments"

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

# Generate JWT_SECRET (32 bytes, hex)
JWT_SECRET="$(openssl rand -hex 32)"
echo "  ✓ IAM_JWT_SECRET generated"
echo "    📝 Value: ${JWT_SECRET:0:16}...${JWT_SECRET: -16}"

# Generate database password (16 bytes)
DB_PASSWORD="$(openssl rand -base64 16 | tr -d '\n')"
echo "  ✓ Database password generated"

# Generate MySQL root password
MYSQL_ROOT_PASSWORD="$(openssl rand -base64 16 | tr -d '\n')"
echo "  ✓ MySQL root password generated"

# Generate Passport RSA Keys (2048 bits - fast, sufficient for local dev)
echo "  ⏳ Generating Passport RSA keys (this may take a moment)..."
PASSPORT_PRIVATE_TEMP=$(mktemp)
PASSPORT_PUBLIC_TEMP=$(mktemp)

openssl genrsa -out "${PASSPORT_PRIVATE_TEMP}" 2048 2>/dev/null
openssl rsa -in "${PASSPORT_PRIVATE_TEMP}" -pubout -out "${PASSPORT_PUBLIC_TEMP}" 2>/dev/null

# Read keys and escape for sed
PASSPORT_PRIVATE_KEY=$(cat "${PASSPORT_PRIVATE_TEMP}" | sed 's/$/\\/' | tr -d '\n' | sed 's/\\$//')
PASSPORT_PUBLIC_KEY=$(cat "${PASSPORT_PUBLIC_TEMP}" | sed 's/$/\\/' | tr -d '\n' | sed 's/\\$//')

rm -f "${PASSPORT_PRIVATE_TEMP}" "${PASSPORT_PUBLIC_TEMP}"
echo "  ✓ Passport RSA keys generated"

echo ""
echo "📝 Updating ${PROD_ENV_FILE} with generated secrets..."

# Use temp file for safer sed replacement
TEMP_FILE="${PROD_ENV_FILE}.tmp"
cp "${PROD_ENV_FILE}" "${TEMP_FILE}"

# Replace placeholders with actual values
sed -i "s|^APP_KEY=.*|APP_KEY=${APP_KEY}|" "${TEMP_FILE}"
sed -i "s|^IAM_JWT_SECRET=.*|IAM_JWT_SECRET=${JWT_SECRET}|" "${TEMP_FILE}"
sed -i "s|^MYSQL_PASSWORD=.*|MYSQL_PASSWORD=${DB_PASSWORD}|" "${TEMP_FILE}"
sed -i "s|^MYSQL_ROOT_PASSWORD=.*|MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}|" "${TEMP_FILE}"

# For Passport keys, we need multiline replacement
# Remove old keys and add new ones
sed -i '/^PASSPORT_PRIVATE_KEY=/,/^-----END PRIVATE KEY-----/c\PASSPORT_PRIVATE_KEY="'"${PASSPORT_PRIVATE_KEY}"'"' "${TEMP_FILE}"
sed -i '/^PASSPORT_PUBLIC_KEY=/,/^-----END PUBLIC KEY-----/c\PASSPORT_PUBLIC_KEY="'"${PASSPORT_PUBLIC_KEY}"'"' "${TEMP_FILE}"

mv "${TEMP_FILE}" "${PROD_ENV_FILE}"
echo "✅ Secrets updated in ${PROD_ENV_FILE}"

# Final validation
echo ""
echo "🔍 Validating environment file..."
SESSION_DOMAIN_VAL=$(grep '^SESSION_DOMAIN=' "${PROD_ENV_FILE}" | cut -d '=' -f 2)
SESSION_SAME_SITE_VAL=$(grep '^SESSION_SAME_SITE=' "${PROD_ENV_FILE}" | cut -d '=' -f 2)
FINAL_JWT=$(grep '^IAM_JWT_SECRET=' "${PROD_ENV_FILE}" | cut -d '=' -f 2 | tr -d ' ')

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

echo ""
echo "======================================"
echo "🎉 Production Environment Generated!"
echo "======================================"
echo ""
echo "📁 Environment file: ${PROD_ENV_FILE}"
echo "🔐 Generated JWT Secret:"
echo "   ${FINAL_JWT:0:16}...${FINAL_JWT: -16}"
echo ""
echo "📋 Summary:"
echo "   • APP_KEY: Generated ✓"
echo "   • IAM_JWT_SECRET: Generated ✓"
echo "   • Database credentials: Generated ✓"
echo "   • Passport RSA keys: Generated ✓"
echo ""
echo "⚠️  IMPORTANT: This file is in .gitignore - DO NOT commit!"
echo ""
echo "📌 NEXT STEPS (in order):"
echo "   1. Run ./prepare-siimut.sh  (will sync JWT secret from this file)"
echo "   2. Run ./build-iam.sh        (build IAM Docker image)"
echo "   3. Run docker compose up     (start all services)"