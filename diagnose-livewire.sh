#!/bin/bash

###############################################################################
# Server Livewire 404 - Quick Diagnosis & Recovery Script
# 
# Use this script to quickly diagnose and fix Livewire 404 issues 
# on production server with docker-compose-multi-apps.yml
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOCKER_COMPOSE_FILE="${1:-docker-compose-multi-apps.yml}"

echo -e "${BLUE}======================================"
echo "🔍 Livewire 404 - Server Diagnosis Tool"
echo "======================================${NC}\n"

# Check if compose file exists
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo -e "${RED}❌ ERROR: File not found: $DOCKER_COMPOSE_FILE${NC}"
    exit 1
fi

# Detect app containers from compose file (app, queue, scheduler)
APP_CONTAINERS=$(grep "container_name:" "$DOCKER_COMPOSE_FILE" | grep -E "siimut|ikp|iam" | sed 's/.*container_name: //' | sort -u)

echo -e "${YELLOW}Detected containers:${NC}"
echo "$APP_CONTAINERS" | sed 's/^/  /'
echo ""

# Function to check single container
check_app() {
    local CONTAINER=$1
    
    # Extract app name and type from container name
    # siimut-app -> siimut, siimut-queue -> siimut, etc
    local APP_NAME=$(echo "$CONTAINER" | sed 's/-\(app\|queue\|scheduler\)$//')
    local CONTAINER_TYPE=$(echo "$CONTAINER" | sed 's/^[^-]*-//')
    local APP_PATH="/var/www/$APP_NAME"
    
    echo -e "\n${BLUE}═══ Checking: $CONTAINER (type: $CONTAINER_TYPE) ═══${NC}"
    
    # 1. Check if container exists and is running
    if ! docker compose -f "$DOCKER_COMPOSE_FILE" ps "$CONTAINER" 2>/dev/null | grep -q "Up"; then
        echo -e "${RED}  ❌ Container not running: $CONTAINER${NC}"
        return 1
    fi
    echo -e "${GREEN}  ✅ Container is running${NC}"
    
    # 2. Check Livewire folder
    if docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "${APP}-app" test -d "${APP_PATH}/public/vendor/livewire" 2>/dev/null; then
        echo -e "${GREEN}  ✅ Folder exists: public/vendor/livewire/${NC}"
        
        # 3. Check main file
        if docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "${APP}-app" test -f "${APP_PATH}/public/vendor/livewire/livewire.min.js" 2>/dev/null; then
            FILE_SIZE=$(docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "${APP}-app" stat -c%s "${APP_PATH}/public/vendor/livewire/livewire.min.js" 2>/dev/null || echo "unknown")
            echo -e "${GREEN}  ✅ File exists: livewire.min.js ($FILE_SIZE bytes)${NC}"
        else
            echo -e "${RED}  ❌ File missing: livewire.min.js${NC}"
        fi
        
        # 4. Check symlink
        if docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "${APP}-app" test -L "${APP_PATH}/public/livewire" 2>/dev/null; then
            TARGET=$(docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "${APP}-app" readlink "${APP_PATH}/public/livewire" 2>/dev/null)
            echo -e "${GREEN}  ✅ Symlink exists: public/livewire -> $TARGET${NC}"
        else
            echo -e "${YELLOW}  ⚠️  Symlink missing (but folder might still work)${NC}"
        fi
    else
        echo -e "${RED}  ❌ Folder NOT FOUND: public/vendor/livewire/${NC}"
        
        # Debug
        echo -e "${YELLOW}  📋 Contents of public/vendor/:${NC}"
        docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "${APP}-app" sh -c "ls -1 ${APP_PATH}/public/vendor/ 2>/dev/null || echo '(directory empty or not found)'" | sed 's/^/    /'
        
        return 1
    fi
    
    return 0
}

# Function to fix app
fix_app() {
    local APP=$1
    local APP_PATH="/var/www/$APP"
    
    echo -e "\n${BLUE}🔧 Attempting to fix: $APP${NC}"
    
    # Run publish command
    echo -e "  📦 Running livewire:publish..."
    if docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "${APP}-app" sh -c "cd ${APP_PATH} && php artisan livewire:publish --assets" 2>&1 | tail -3; then
        echo -e "${GREEN}  ✓ Publish command completed${NC}"
    else
        echo -e "${YELLOW}  ⚠️ Publish command had issues${NC}"
    fi
    
    # Verify
    echo -e "  🔍 Verifying..."
    check_app "$APP"
}

# Main menu
show_menu() {
    echo -e "\n${BLUE}Select action:${NC}"
    echo "  1) Diagnose all apps"
    echo "  2) Diagnose and attempt fix (if broken)"
    echo "  3) Force fix all apps"
    echo "  4) Show detailed logs for an app"
    echo "  5) Exit"
    echo -n "Choice [1-5]: "
}

# Main loop
while true; do
    show_menu
    read choice
    
    case $choice in
        1)
            echo -e "\n${BLUE}📊 Running diagnosis...${NC}"
            ALL_OK=true
            for APP in $APPS; do
                if ! check_app "$APP"; then
                    ALL_OK=false
                fi
            done
            
            if [ "$ALL_OK" = "true" ]; then
                echo -e "\n${GREEN}✅ All apps OK!${NC}"
            else
                echo -e "\n${RED}⚠️  Some issues found${NC}"
            fi
            ;;
        
        2)
            echo -e "\n${BLUE}🔧 Running diagnosis with auto-fix...${NC}"
            for APP in $APPS; do
                if ! check_app "$APP"; then
                    fix_app "$APP"
                fi
            done
            ;;
        
        3)
            echo -e "\n${YELLOW}⚠️  Force fixing all apps...${NC}"
            for APP in $APPS; do
                fix_app "$APP"
            done
            ;;
        
        4)
            echo -n "App name [siimut/ikp/iam]: "
            read app_name
            echo -e "\n${BLUE}📋 Entrypoint logs for $app_name:${NC}"
            docker compose -f "$DOCKER_COMPOSE_FILE" logs "app-${app_name}" --tail=50 | grep -E "Livewire|icture|vendor|publish" || echo "No Livewire-related logs found"
            
            echo -e "\n${BLUE}📋 Publish log (if exists):${NC}"
            docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "app-${app_name}" cat /tmp/livewire-publish.log 2>/dev/null || echo "Log not found"
            ;;
        
        5)
            echo -e "\n${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        
        *)
            echo -e "${RED}❌ Invalid choice${NC}"
            ;;
    esac
done
