#!/bin/bash

# Quick Laravel Update Script
# For updating application after code changes

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SITE_DIR="./site/si-imut"

echo -e "${BLUE}🔄 Quick Laravel Update${NC}"
echo "======================"

if [ ! -d "$SITE_DIR" ]; then
    echo -e "${RED}❌ Site directory not found: $SITE_DIR${NC}"
    exit 1
fi

cd "$SITE_DIR"

echo -e "${YELLOW}📂 Working in: $(pwd)${NC}"

# Git pull latest changes
echo -e "${BLUE}📥 Pulling latest changes...${NC}"
git pull origin fix-chart
echo -e "${GREEN}✅ Code updated${NC}"

# Update composer dependencies if composer.json changed
if git diff HEAD~1 --name-only | grep -q "composer.json\|composer.lock"; then
    echo -e "${BLUE}📦 Updating Composer dependencies...${NC}"
    composer update --no-dev --optimize-autoloader
    echo -e "${GREEN}✅ Composer updated${NC}"
fi

# Update npm dependencies if package.json changed
if git diff HEAD~1 --name-only | grep -q "package.json\|package-lock.json"; then
    echo -e "${BLUE}📦 Updating npm dependencies...${NC}"
    npm update
    echo -e "${GREEN}✅ npm updated${NC}"
fi

# Rebuild assets if frontend files changed
if git diff HEAD~1 --name-only | grep -qE "resources/|vite.config.js|tailwind.config.js|package"; then
    echo -e "${BLUE}🏗️  Rebuilding assets...${NC}"
    npm run build
    echo -e "${GREEN}✅ Assets rebuilt${NC}"
fi

# Clear caches
echo -e "${BLUE}🧹 Clearing caches...${NC}"
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# Optimize application
echo -e "${BLUE}⚡ Re-optimizing application...${NC}"
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo -e "${GREEN}✅ Caches optimized${NC}"

# Check if migration files changed
if git diff HEAD~1 --name-only | grep -q "database/migrations/"; then
    echo -e "${YELLOW}🗄️  Database migrations detected${NC}"
    read -p "Run migrations? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        php artisan migrate --force
        echo -e "${GREEN}✅ Migrations completed${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🎉 Application updated successfully!${NC}"
echo -e "${BLUE}Restart containers if needed: docker compose -f docker-compose-new.yml restart${NC}"