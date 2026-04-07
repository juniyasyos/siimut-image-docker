#!/bin/bash

echo "=========================================="
echo "SIMULATE ACTUAL LOGIN FLOW"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

COOKIE_JAR="/tmp/siimut_login.txt"
rm -f "$COOKIE_JAR"

BASE="http://127.0.0.1"
SIIMUT="$BASE:8000"
IAM="$BASE:8100"

echo -e "${YELLOW}=== STEP 1: Get SIIMUT Login Page ===${NC}"
echo "Request: GET $SIIMUT/siimut/login"
STEP1=$(curl -s -i -c "$COOKIE_JAR" "$SIIMUT/siimut/login" 2>&1)
echo "$STEP1" | head -40
REDIRECT=$(echo "$STEP1" | grep -i "location:" | head -1 | cut -d' ' -f2- | tr -d '\r')
echo ""
if [ ! -z "$REDIRECT" ]; then
    echo -e "${GREEN}✓ Redirect detected: $REDIRECT${NC}"
else
    echo -e "${RED}✗ No redirect found${NC}"
fi
echo ""

echo -e "${YELLOW}=== STEP 2: Follow Redirect (if any) ===${NC}"
if [ ! -z "$REDIRECT" ]; then
    echo "Request: GET $REDIRECT"
    STEP2=$(curl -s -i -b "$COOKIE_JAR" "$REDIRECT" 2>&1)
    echo "$STEP2" | head -40
    echo ""
fi

echo -e "${YELLOW}=== STEP 3: Check Cookies Set ===${NC}"
if [ -f "$COOKIE_JAR" ]; then
    echo "Cookies:"
    cat "$COOKIE_JAR"
    echo ""
fi

echo -e "${YELLOW}=== STEP 4: Extract OAuth Token from URL ===${NC}"
echo "If you see ?code= in the URL above, extract it here..."
echo "Looking for auth_code or state parameters in flow..."
echo ""

echo -e "${YELLOW}=== STEP 5: Detailed SIIMUT Log During Login ===${NC}"
echo "Clearing old logs and attempting fresh login..."
docker compose -f docker-compose-multi-apps.yml logs app-siimut --tail 5 > /tmp/siimut_log_before.txt 2>&1

echo "Making login request..."
curl -s -i -c "$COOKIE_JAR" "$SIIMUT/siimut/login" > /dev/null 2>&1
sleep 2

echo "New SIIMUT logs:"
docker compose -f docker-compose-multi-apps.yml logs app-siimut --tail 20 2>&1
echo ""

echo -e "${YELLOW}=== STEP 6: Detailed IAM Log During Token Exchange ===${NC}"
echo "Recent IAM logs:"
docker compose -f docker-compose-multi-apps.yml logs app-iam --tail 20 2>&1
echo ""

echo -e "${YELLOW}=== STEP 7: Full Nginx Access Log (8000 port) ===${NC}"
echo "Checking all requests to port 8000..."
docker compose -f docker-compose-multi-apps.yml exec -T web tail -30 /var/log/nginx/siimut_access.log 2>&1 || echo "Cannot read nginx log"
echo ""

echo -e "${YELLOW}=== STEP 8: Check Browser Response Headers ===${NC}"
echo "Simulating browser request to /siimut/login..."
curl -v -c "$COOKIE_JAR" "$SIIMUT/siimut/login" 2>&1 | grep -E "^>|^<|^Location:|Set-Cookie:|redirect" | head -30
echo ""

echo -e "${YELLOW}=== STEP 9: Check if SSO Callback is the Problem ===${NC}"
echo "Testing SSO callback endpoint..."
echo "GET $SIIMUT/sso/callback?code=test&state=test"
curl -s -i "$SIIMUT/sso/callback?code=test&state=test" 2>&1 | head -20
echo ""

echo -e "${YELLOW}=== STEP 10: Check Laravel Routes ===${NC}"
echo "SIIMUT SSO-related routes:"
docker compose -f docker-compose-multi-apps.yml exec -T app-siimut php artisan route:list 2>&1 | grep -i "sso\|login\|callback" | head -20
echo ""

echo -e "${YELLOW}=== ANALYSIS ===${NC}"
echo "✓ Login page accessible?"
echo "✓ Is there a redirect?"
echo "✓ Where does it redirect to?"
echo "✓ Are session cookies being set?"
echo "✓ Any errors in SIIMUT logs?"
echo "✓ Any errors in IAM logs?"
echo "✓ What's the exact error message?"
echo ""
