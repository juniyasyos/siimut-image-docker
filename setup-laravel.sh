#!/bin/bash

# Laravel Setup Script - Outside Container
# This script sets up Laravel application dependencies and builds assets

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SITE_DIR="./site/si-imut"
ENV_FILE=".env"
ENV_EXAMPLE=".env.example"

echo -e "${BLUE}🚀 Laravel Application Setup${NC}"
echo "=================================="

# Check if site directory exists
if [ ! -d "$SITE_DIR" ]; then
    echo -e "${RED}❌ Site directory not found: $SITE_DIR${NC}"
    echo "Please run ./setup-siimut-new.sh first to clone the repository"
    exit 1
fi

cd "$SITE_DIR"

echo -e "${YELLOW}📂 Working directory: $(pwd)${NC}"
echo ""

# Step 1: Check dependencies
echo -e "${BLUE}📋 Checking dependencies...${NC}"

# Check PHP
if ! command -v php &> /dev/null; then
    echo -e "${RED}❌ PHP not found. Please install PHP 8.2 or higher${NC}"
    exit 1
fi

# Check Composer
if ! command -v composer &> /dev/null; then
    echo -e "${RED}❌ Composer not found. Please install Composer${NC}"
    exit 1
fi

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js not found. Please install Node.js and npm${NC}"
    exit 1
fi

# Check npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ npm not found. Please install npm${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All dependencies found${NC}"
echo ""

# Step 2: Create .env file
echo -e "${BLUE}🔧 Setting up environment configuration...${NC}"

if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_EXAMPLE" ]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        echo -e "${GREEN}✅ Created .env from .env.example${NC}"
    else
        echo -e "${RED}❌ No .env.example found${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  .env file already exists${NC}"
fi

# Update .env with Docker database settings
echo -e "${BLUE}🔧 Updating .env for Docker environment...${NC}"

# Update database configuration
sed -i 's/DB_HOST=.*/DB_HOST=127.0.0.1/' "$ENV_FILE"
sed -i 's/DB_PORT=.*/DB_PORT=3306/' "$ENV_FILE"
sed -i 's/DB_DATABASE=.*/DB_DATABASE=siimut_prod/' "$ENV_FILE"
sed -i 's/DB_USERNAME=.*/DB_USERNAME=root/' "$ENV_FILE"
sed -i 's/DB_PASSWORD=.*/DB_PASSWORD=root/' "$ENV_FILE"

# Update Redis configuration
sed -i 's/REDIS_HOST=.*/REDIS_HOST=127.0.0.1/' "$ENV_FILE"
sed -i 's/REDIS_PORT=.*/REDIS_PORT=6379/' "$ENV_FILE"

echo -e "${GREEN}✅ Environment configured${NC}"
echo ""

# Step 3: Install Composer dependencies
echo -e "${BLUE}📦 Installing Composer dependencies...${NC}"

if [ ! -d "vendor" ]; then
    composer install --no-dev --optimize-autoloader
    echo -e "${GREEN}✅ Composer dependencies installed${NC}"
else
    echo -e "${YELLOW}⚠️  Vendor directory exists, running composer update...${NC}"
    composer update --no-dev --optimize-autoloader
    echo -e "${GREEN}✅ Composer dependencies updated${NC}"
fi
echo ""

# Step 4: Generate application key
echo -e "${BLUE}🔑 Generating application key...${NC}"
php artisan key:generate --force
echo -e "${GREEN}✅ Application key generated${NC}"
echo ""

# Step 5: Install and build npm dependencies
echo -e "${BLUE}🎨 Installing and building frontend assets...${NC}"

if [ ! -d "node_modules" ]; then
    npm install
    echo -e "${GREEN}✅ npm dependencies installed${NC}"
else
    echo -e "${YELLOW}⚠️  node_modules exists, running npm update...${NC}"
    npm update
    echo -e "${GREEN}✅ npm dependencies updated${NC}"
fi

# Build assets
echo -e "${BLUE}🏗️  Building production assets...${NC}"
npm run build
echo -e "${GREEN}✅ Assets built successfully${NC}"
echo ""

# Step 6: Laravel optimizations
echo -e "${BLUE}⚡ Optimizing Laravel application...${NC}"

# Clear all caches first
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# Generate optimized caches
php artisan config:cache
php artisan route:cache
php artisan view:cache

echo -e "${GREEN}✅ Laravel optimizations completed${NC}"
echo ""

# Step 7: Set proper permissions
echo -e "${BLUE}🔒 Setting file permissions...${NC}"

# Create directories if they don't exist
mkdir -p storage/logs
mkdir -p storage/framework/cache
mkdir -p storage/framework/sessions
mkdir -p storage/framework/views
mkdir -p bootstrap/cache

# Set permissions
chmod -R 775 storage
chmod -R 775 bootstrap/cache
chmod +x artisan

echo -e "${GREEN}✅ Permissions set${NC}"
echo ""

# Step 8: Database migration (optional)
echo -e "${BLUE}💾 Database setup...${NC}"
echo -e "${YELLOW}Note: Make sure Docker containers are running before database operations${NC}"

read -p "Do you want to run database migrations? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🗄️  Running database migrations...${NC}"
    php artisan migrate --force
    echo -e "${GREEN}✅ Database migrations completed${NC}"
    
    read -p "Do you want to seed the database? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}🌱 Seeding database...${NC}"
        php artisan db:seed --force
        echo -e "${GREEN}✅ Database seeded${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🎉 Laravel application setup completed!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Start Docker containers: docker compose -f docker-compose-new.yml up -d"
echo "2. Access application at: http://localhost:8088"
echo "3. Access phpMyAdmin at: http://localhost:8080"
echo ""
echo -e "${YELLOW}📝 Notes:${NC}"
echo "- Application files are in: $SITE_DIR"
echo "- Environment file: $SITE_DIR/$ENV_FILE"
echo "- Make sure to restart containers after setup if they were running"
echo ""