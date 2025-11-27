#!/bin/bash

# SIIMUT Docker Setup Script with Git Clone
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
SIIMUT_REPO="https://github.com/juniyasyos/si-imut.git"
SIIMUT_BRANCH="feat-imutData"
COMPOSE_FILE="docker-compose-multi-apps.yml"
REPO_NAME="si-imut"

echo -e "${GREEN}🚀 SIIMUT Docker Setup${NC}"
echo -e "${GREEN}======================${NC}"# SIIMUT Docker Setup Script
# Script ini akan setup environment dengan git clone

set -e

echo "🚀 SIIMUT Docker Setup"
echo "======================"

# Default values
SIIMUT_REPO=${SIIMUT_REPO:-"https://github.com/juniyasyos/si-imut.git"}
SIIMUT_BRANCH=${SIIMUT_BRANCH:-"fix-chart"}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            SIIMUT_REPO="$2"
            shift 2
            ;;
        --branch)
            SIIMUT_BRANCH="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --repo <url>     Git repository URL (default: https://github.com/juniyasyos/si-imut.git)"
            echo "  --branch <name>  Git branch name (default: fix-chart)"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

# Extract repository name from URL
REPO_NAME=$(basename "$SIIMUT_REPO" .git)

echo -e "${YELLOW}📂 Repository: $SIIMUT_REPO${NC}"
echo -e "${YELLOW}🌿 Branch: $SIIMUT_BRANCH${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required dependencies
echo -e "${BLUE}📋 Checking dependencies...${NC}"

if ! command_exists git; then
    echo -e "${RED}❌ Git is not installed. Please install Git first.${NC}"
    exit 1
fi

if ! command_exists docker; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! command_exists docker-compose; then
    echo -e "${RED}❌ Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All dependencies are installed${NC}"

# Create site directory
mkdir -p site

# Clone or update SIIMUT repository
echo -e "${BLUE}📦 Setting up SIIMUT application...${NC}"

if [ ! -d "site/${REPO_NAME}" ]; then
    echo -e "${YELLOW}📥 Cloning SIIMUT repository...${NC}"
    git clone --depth 1 -b "${SIIMUT_BRANCH}" "${SIIMUT_REPO}" "site/${REPO_NAME}"
    echo -e "${GREEN}✅ Repository cloned successfully${NC}"
elif [ -d "site/${REPO_NAME}/.git" ]; then
    echo -e "${YELLOW}🔄 Updating existing repository...${NC}"
    cd "site/${REPO_NAME}"
    git fetch origin "${SIIMUT_BRANCH}"
    git checkout "${SIIMUT_BRANCH}"
    git pull origin "${SIIMUT_BRANCH}"
    cd ../..
    echo -e "${GREEN}✅ Repository updated successfully${NC}"
else
    echo -e "${RED}❌ Site/${REPO_NAME} directory exists but is not a git repository${NC}"
    echo -e "${YELLOW}Please remove the site/${REPO_NAME} directory and run again${NC}"
    exit 1
fi

# Create required directories
echo -e "${BLUE}📁 Creating required directories...${NC}"
mkdir -p Docker/{caddy/{data,config},db/{data,sql},redis/data,phpmyadmin/sessions,logs}

# Set proper permissions
echo -e "${BLUE}🔒 Setting proper permissions...${NC}"
chmod 755 Docker/phpmyadmin/sessions
chown -R 33:33 Docker/phpmyadmin/sessions 2>/dev/null || true

# Create environment file if not exists
if [ ! -f ".env" ]; then
    echo -e "${BLUE}⚙️  Creating environment configuration...${NC}"
    cat > .env << EOF
# Application
APP_NAME=SIIMUT
APP_ENV=local
APP_PORT=8000

# Database
MYSQL_ROOT_PASSWORD=secret123
MYSQL_DATABASE=siimut
MYSQL_USER=siimut
MYSQL_PASSWORD=secret123
MYSQL_PORT=3306

# phpMyAdmin
PMA_PORT=8080

# Redis
REDIS_PORT=6379

# Git Repository (for reference)
SIIMUT_REPO=${SIIMUT_REPO}
SIIMUT_BRANCH=${SIIMUT_BRANCH}
REPO_NAME=${REPO_NAME}
EOF
    echo -e "${GREEN}✅ Environment file created${NC}"
else
    echo -e "${YELLOW}⚠️  Environment file already exists, skipping...${NC}"
fi

# Make entrypoint script executable
if [ -f "Docker/php/entrypoint.sh" ]; then
    chmod +x Docker/php/entrypoint.sh
    echo -e "${GREEN}✅ Entrypoint script made executable${NC}"
fi

# Check if Caddy config exists
if [ ! -f "Docker/caddy/Caddyfile" ]; then
    echo -e "${RED}❌ Caddyfile not found. Please create Docker/caddy/Caddyfile${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 SIIMUT setup completed successfully!${NC}"
echo ""
echo -e "${BLUE}� Project Structure:${NC}"
echo -e "${YELLOW}• Docker configs:${NC} ./Docker/"
echo -e "${YELLOW}• Application code:${NC} ./site/${REPO_NAME}/"
echo -e "${YELLOW}• Environment:${NC} ./.env"
echo ""
echo -e "${BLUE}�📋 Next steps:${NC}"
echo -e "${YELLOW}1. Start services:${NC} docker-compose -f ${COMPOSE_FILE} up -d"
echo -e "${YELLOW}2. Check status:${NC} docker-compose -f ${COMPOSE_FILE} ps"
echo -e "${YELLOW}3. View logs:${NC} docker-compose -f ${COMPOSE_FILE} logs -f"
echo ""
echo -e "${BLUE}🌐 Access URLs:${NC}"
echo -e "${YELLOW}• Application:${NC} http://localhost:8000"
echo -e "${YELLOW}• phpMyAdmin:${NC} http://localhost:8080"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"