#!/bin/bash

# SIIMUT Code Update Script
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Default values
PROJECT_NAME="si-imut"
BRANCH=""
COMPOSE_FILE="docker-compose-new.yml"
ENV_FILE=".env.development"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -e|--env)
            ENV_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -p, --project    Project name in site/ folder (default: si-imut)"
            echo "  -b, --branch     Git branch to checkout"
            echo "  -e, --env        Environment file (default: .env.development)"
            echo "  -h, --help       Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

PROJECT_PATH="site/${PROJECT_NAME}"

echo -e "${GREEN}🔄 Updating ${PROJECT_NAME}...${NC}"

# Check if project exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}❌ Project not found: $PROJECT_PATH${NC}"
    exit 1
fi

# Check if it's a git repository
if [ ! -d "$PROJECT_PATH/.git" ]; then
    echo -e "${RED}❌ Not a git repository: $PROJECT_PATH${NC}"
    exit 1
fi

cd "$PROJECT_PATH"

# Get current branch if not specified
if [ -z "$BRANCH" ]; then
    BRANCH=$(git branch --show-current)
    echo -e "${YELLOW}📝 Using current branch: $BRANCH${NC}"
fi

# Update code
echo -e "${YELLOW}📥 Pulling latest changes from $BRANCH...${NC}"
git fetch origin
git checkout "$BRANCH"
git pull origin "$BRANCH"

cd ../..

# Check if composer.json changed (need to install dependencies)
if git diff HEAD~1 HEAD --name-only | grep -q "composer.json\|composer.lock"; then
    echo -e "${YELLOW}📦 Installing/updating Composer dependencies...${NC}"
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec php composer install --no-dev --optimize-autoloader
fi

# Check if package.json changed (need to build assets)
if git diff HEAD~1 HEAD --name-only | grep -q "package.json\|package-lock.json"; then
    echo -e "${YELLOW}🔨 Installing NPM dependencies and building assets...${NC}"
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec php sh -c "npm install && npm run build"
fi

# Run migrations if needed
echo -e "${YELLOW}🗄️  Running database migrations...${NC}"
docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec php php artisan migrate --force

# Clear caches
echo -e "${YELLOW}🧹 Clearing caches...${NC}"
docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec php php artisan config:cache
docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec php php artisan route:cache
docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec php php artisan view:cache

# Restart services
echo -e "${YELLOW}🔄 Restarting services...${NC}"
docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" restart php worker

# Health check
echo -e "${YELLOW}🏥 Performing health check...${NC}"
sleep 5

if curl -f -s http://localhost:8000 > /dev/null; then
    echo -e "${GREEN}✅ Update completed successfully!${NC}"
    echo -e "${GREEN}🌐 Application is running at http://localhost:8000${NC}"
else
    echo -e "${RED}❌ Health check failed!${NC}"
    echo -e "${YELLOW}📋 Check logs: docker-compose -f $COMPOSE_FILE logs php${NC}"
    exit 1
fi