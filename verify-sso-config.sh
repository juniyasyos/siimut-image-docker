#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🧪 SSO/JWT Configuration Verification Script${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

cd /home/juni/projects/siimut-docker

# Check 1: JWT Secrets Match
echo -e "${YELLOW}[1/6] Checking JWT Secrets Match...${NC}"
echo "─────────────────────────────────────────"
IAM_SECRET=$(docker exec iam-app cat /var/www/iam/.env 2>/dev/null | grep "^IAM_JWT_SECRET=" | cut -d'=' -f2)
SIIMUT_SECRET=$(docker exec siimut-app cat /var/www/siimut/.env 2>/dev/null | grep "^IAM_JWT_SECRET=" | cut -d'=' -f2)

if [ "$IAM_SECRET" = "$SIIMUT_SECRET" ] && [ ! -z "$IAM_SECRET" ]; then
    echo -e "${GREEN}✓ JWT Secrets MATCH${NC}"
    echo "  Secret: ${IAM_SECRET:0:20}...${IAM_SECRET: -10}"
else
    echo -e "${RED}✗ JWT Secrets DO NOT MATCH${NC}"
    echo "  IAM:    ${IAM_SECRET:0:20}..."
    echo "  SIIMUT: ${SIIMUT_SECRET:0:20}..."
fi
echo ""

# Check 2: Refresh Token Endpoint Configuration
echo -e "${YELLOW}[2/6] Checking Refresh Token Endpoint...${NC}"
echo "─────────────────────────────────────────"
REFRESH_ENDPOINT=$(docker exec siimut-app cat /var/www/siimut/.env 2>/dev/null | grep "IAM_REFRESH_TOKEN_ENDPOINT=")

if echo "$REFRESH_ENDPOINT" | grep -q "http://web:8100"; then
    echo -e "${GREEN}✓ Refresh Endpoint uses Docker network (web:8100)${NC}"
    echo "  Config: $REFRESH_ENDPOINT"
elif echo "$REFRESH_ENDPOINT" | grep -q "127.0.0.1"; then
    echo -e "${RED}✗ Refresh Endpoint uses localhost (127.0.0.1)${NC}"
    echo "  Config: $REFRESH_ENDPOINT"
    echo "  This will FAIL inside containers - needs to be web:8100"
else
    echo -e "${YELLOW}⚠ Refresh Endpoint not found or not set${NC}"
fi
echo ""

# Check 3: Verify Endpoint Configuration
echo -e "${YELLOW}[3/6] Checking Verify Endpoint...${NC}"
echo "─────────────────────────────────────────"
VERIFY_ENDPOINT=$(docker exec siimut-app cat /var/www/siimut/.env 2>/dev/null | grep "IAM_VERIFY_ENDPOINT=")

if echo "$VERIFY_ENDPOINT" | grep -q "http://web:8100"; then
    echo -e "${GREEN}✓ Verify Endpoint uses Docker network (web:8100)${NC}"
    echo "  Config: $VERIFY_ENDPOINT"
elif echo "$VERIFY_ENDPOINT" | grep -q "127.0.0.1"; then
    echo -e "${RED}✗ Verify Endpoint uses localhost (127.0.0.1)${NC}"
    echo "  Config: $VERIFY_ENDPOINT"
else
    echo -e "${YELLOW}⚠ Verify Endpoint uses template variable${NC}"
    echo "  Config: $VERIFY_ENDPOINT"
fi
echo ""

# Check 4: Test Token Refresh Connectivity
echo -e "${YELLOW}[4/6] Testing Token Refresh Endpoint Connectivity...${NC}"
echo "─────────────────────────────────────────"
CURL_RESULT=$(docker exec siimut-app curl -s -m 3 -w "\n%{http_code}" http://web:8100/api/sso/token/refresh -X POST 2>&1 | tail -1)

if [ ! -z "$CURL_RESULT" ] && [ "$CURL_RESULT" != "7" ]; then
    echo -e "${GREEN}✓ Can reach http://web:8100/api/sso/token/refresh${NC}"
    echo "  HTTP Status: ${CURL_RESULT:0:3}"
    echo "  (Will be 400+ since no valid token, but connection works)"
else
    echo -e "${RED}✗ Cannot reach http://web:8100/api/sso/token/refresh${NC}"
    echo "  Check Docker network connectivity"
fi
echo ""

# Check 5: Test Localhost Connectivity (should fail)
echo -e "${YELLOW}[5/6] Testing Localhost (127.0.0.1:8100) - Should FAIL...${NC}"
echo "─────────────────────────────────────────"
CURL_LOCAL=$(docker exec siimut-app curl -s -m 2 http://127.0.0.1:8100/api/sso/token/refresh -X POST 2>&1)

if echo "$CURL_LOCAL" | grep -q "Failed to connect\|Connection refused"; then
    echo -e "${YELLOW}✓ EXPECTED: Localhost is unreachable from container${NC}"
    echo "  This is why we use Docker network (web:8100)"
else
    echo -e "${BLUE}ℹ Localhost accessible (unusual in Docker)${NC}"
fi
echo ""

# Check 6: Container Health Status
echo -e "${YELLOW}[6/6] Checking Container Health...${NC}"
echo "─────────────────────────────────────────"
docker compose -f docker-compose-multi-apps.yml ps --format "table {{.Name}}\t{{.Status}}"
echo ""

# Summary
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Summary:${NC}"
echo "─────────────────────────────────────────"
echo -e "If all checks are ${GREEN}GREEN✓${NC}, the configuration should be correct."
echo "Run login test: ${YELLOW}http://127.0.0.1:8000${NC}"
echo "Monitor logs: ${YELLOW}docker compose logs app-siimut -f${NC}"
echo ""
echo -e "If still getting 'Signature verification failed',"
echo "check logs for token details and verify JWT algorithm."
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
