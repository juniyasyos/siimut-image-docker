#!/bin/bash

###############################################################################
#  Quick Debug Script - Focus on ROOT PASSWORD ISSUE
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

COMPOSE_FILE="docker-compose.base.yml"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ROOT PASSWORD DEBUG${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}\n"

# Step 1: Check compose file
echo -e "${YELLOW}【1】Checking docker-compose.base.yml${NC}"
echo "   Looking for MYSQL_ROOT_PASSWORD..."
grep -A 2 "MYSQL_ROOT_PASSWORD" "$COMPOSE_FILE" | head -5

# Step 2: Check env file
echo -e "\n${YELLOW}【2】Checking env/.env.db${NC}"
echo "   File contents:"
cat env/.env.db

# Step 3: Check my.cnf
echo -e "\n${YELLOW}【3】Checking DockerNew/db/my.cnf${NC}"
echo "   Looking for password-related settings..."
docker compose -f "$COMPOSE_FILE" exec -T db cat /etc/mysql/conf.d/my.cnf 2>/dev/null | head -30

# Step 4: Check environment inside container
echo -e "\n${YELLOW}【4】Environment Variables in Container${NC}"
docker compose -f "$COMPOSE_FILE" exec -T db bash -c 'echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD"'
docker compose -f "$COMPOSE_FILE" exec -T db bash -c 'echo "MYSQL_RANDOM_ROOT_PASSWORD=$MYSQL_RANDOM_ROOT_PASSWORD"'

# Step 5: Try root connection
echo -e "\n${YELLOW}【5】Testing Root Access${NC}"
echo "   Attempting: mysql -h db -u root -p'rootpass123'"

docker compose -f "$COMPOSE_FILE" exec -T db mysql -h db -u root -p'rootpass123' -e "SELECT 'SUCCESS' AS result;" 2>&1 | tee /tmp/root_test.log

if grep -q "SUCCESS" /tmp/root_test.log; then
    echo -e "${GREEN}✓ ROOT PASSWORD WORKS!${NC}"
else
    echo -e "${RED}✗ ROOT PASSWORD FAILED!${NC}"
    echo ""
    echo -e "${YELLOW}【6】Debug: Trying Alternative Methods${NC}"
    echo ""
    
    echo "Try 1: Without password"
    docker compose -f "$COMPOSE_FILE" exec -T db mysql -h db -u root -e "SELECT 1;" 2>&1 || echo "   Failed"
    echo ""
    
    echo "Try 2: From localhost inside container"
    docker compose -f "$COMPOSE_FILE" exec -T db mysql -h localhost -u root -p'rootpass123' -e "SELECT 1;" 2>&1 || echo "   Failed"
    echo ""
    
    echo "Try 3: Check MySQL error log"
    docker compose -f "$COMPOSE_FILE" exec -T db tail -50 /var/log/mysql/error.log 2>/dev/null || echo "   (no error log)"
    echo ""
    
    echo -e "${YELLOW}【SOLUTIONS】${NC}"
    echo "1. Restart database:"
    echo "   docker compose -f $COMPOSE_FILE restart db"
    echo ""
    echo "2. Rebuild database (WARNING: removes all data):"
    echo "   docker compose -f $COMPOSE_FILE down -v"
    echo "   docker compose -f $COMPOSE_FILE up -d"
    echo ""
    echo "3. Rebuild database with fresh SQL init:"
    echo "   docker compose -f $COMPOSE_FILE down -v"
    echo "   rm -rf Docker/db/data/*"
    echo "   docker compose -f $COMPOSE_FILE up -d"
    echo ""
    echo "4. Check MySQL 8.0 auth plugin:"
    echo "   docker compose -f $COMPOSE_FILE exec db mysql -h db -u root -e 'SELECT user, host, plugin FROM mysql.user;' 2>/dev/null || true"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "✓ Debug Complete"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
