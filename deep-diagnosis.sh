#!/bin/bash

echo "=========================================="
echo "DEEP LOGIN FLOW DIAGNOSTICS"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Check database Applications config
echo -e "${YELLOW}1. DATABASE - APPLICATIONS TABLE${NC}"
echo "Checking redirect_uris in database..."
docker compose -f docker-compose-multi-apps.yml exec -T database-service mysql -u iam_user -piam-password iam_db -e \
"SELECT id, key, name, redirect_uris FROM applications WHERE key='siimut';" 2>&1
echo ""

# 2. Test actual token generation
echo -e "${YELLOW}2. TEST TOKEN GENERATION${NC}"
echo "Generate test access token from IAM..."
TOKEN=$(docker compose -f docker-compose-multi-apps.yml exec -T app-iam php -r "
require 'vendor/autoload.php';
\$app = require 'bootstrap/app.php';
\$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

\$user = \App\Models\User::first();
if (\$user) {
    \$token = \$user->createToken('test')->plainTextToken;
    echo \$token;
} else {
    echo 'ERROR: No users found';
}
" 2>&1)

echo "Token generated (first 50 chars): ${TOKEN:0:50}..."
echo ""

# Decode JWT without verification to see payload
echo -e "${YELLOW}3. DECODE TOKEN PAYLOAD${NC}"
if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "ERROR: No users found" ]; then
    IFS='.' read -r HEADER PAYLOAD FOOTER <<< "$TOKEN"
    # Add padding
    PAYLOAD_PADDED="${PAYLOAD}$(printf '%*s' $(( (4 - ${#PAYLOAD} % 4) % 4 )) | tr ' ' '=')"
    DECODED=$(echo "$PAYLOAD_PADDED" | base64 -d 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "JWT Payload (decoded):"
        echo "$DECODED" | jq '.' 2>/dev/null || echo "$DECODED"
    else
        echo "❌ Could not decode JWT"
    fi
else
    echo "❌ No token to decode"
fi
echo ""

# 3. Test SIIMUT verify endpoint with real token
echo -e "${YELLOW}4. TEST SIIMUT VERIFY ENDPOINT${NC}"
if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "ERROR: No users found" ]; then
    echo "Testing: POST http://127.0.0.1:8000/api/sso/verify"
    VERIFY_RESPONSE=$(curl -s -X GET \
        -H "Authorization: Bearer $TOKEN" \
        http://127.0.0.1:8000/api/sso/verify)
    
    echo "Response:"
    echo "$VERIFY_RESPONSE" | jq '.' 2>/dev/null || echo "$VERIFY_RESPONSE"
else
    echo "❌ Skipped - no token available"
fi
echo ""

# 4. Check session handling
echo -e "${YELLOW}5. SESSION CONFIGURATION${NC}"
echo "Check SESSION_DRIVER and SESSION settings:"
docker compose -f docker-compose-multi-apps.yml exec -T app-siimut php -r "
require 'vendor/autoload.php';
\$app = require 'bootstrap/app.php';
\$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

echo 'SIIMUT Session Driver: ' . config('session.driver') . PHP_EOL;
echo 'SIIMUT Session Domain: ' . config('session.domain') . PHP_EOL;
echo 'SIIMUT Session Lifetime: ' . config('session.lifetime') . PHP_EOL;
echo 'SIIMUT CSRF Enabled: ' . (config('csrf_protection') ? 'true' : 'false') . PHP_EOL;
" 2>&1

echo ""
docker compose -f docker-compose-multi-apps.yml exec -T app-iam php -r "
require 'vendor/autoload.php';
\$app = require 'bootstrap/app.php';
\$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

echo 'IAM Session Driver: ' . config('session.driver') . PHP_EOL;
echo 'IAM Session Domain: ' . config('session.domain') . PHP_EOL;
" 2>&1
echo ""

# 5. Test actual login page
echo -e "${YELLOW}6. TEST SIIMUT LOGIN PAGE REQUEST${NC}"
echo "GET http://127.0.0.1:8000/siimut/login (follow 1 redirect max)"
curl -s -i -L --max-redirs 1 http://127.0.0.1:8000/siimut/login 2>&1 | head -50
echo ""

# 6. Check middleware - CSRF
echo -e "${YELLOW}7. CSRF & AUTH MIDDLEWARE CHECK${NC}"
echo "Checking SIIMUT auth routes..."
docker compose -f docker-compose-multi-apps.yml exec -T app-siimut grep -r "csrf\|middleware" routes/api.php 2>/dev/null | head -10
echo ""

# 7. Check logs for actual error
echo -e "${YELLOW}8. SIIMUT RECENT ERROR LOGS${NC}"
echo "Looking for redirect or verification errors..."
SIIMUT_LOGS=$(docker compose -f docker-compose-multi-apps.yml logs app-siimut --tail=50 2>&1 | grep -i "redirect\|error\|signature\|token\|sso" | head -20)
if [ -z "$SIIMUT_LOGS" ]; then
    echo "No error logs found"
else
    echo "$SIIMUT_LOGS"
fi
echo ""

echo -e "${YELLOW}9. IAM RECENT LOGS${NC}"
echo "Looking for token issues..."
IAM_LOGS=$(docker compose -f docker-compose-multi-apps.yml logs app-iam --tail=50 2>&1 | grep -i "error\|token\|sso" | head -20)
if [ -z "$IAM_LOGS" ]; then
    echo "No error logs found"
else
    echo "$IAM_LOGS"
fi
echo ""

echo -e "${YELLOW}10. NGINX LOGS - SIIMUT REDIRECTS${NC}"
echo "Checking nginx redirect patterns..."
NGINX_LOGS=$(docker compose -f docker-compose-multi-apps.yml logs web --tail=100 2>&1 | grep -i "siimut\|8000\|redirect" | head -15)
if [ -z "$NGINX_LOGS" ]; then
    echo "No nginx redirects found"
else
    echo "$NGINX_LOGS"
fi
echo ""

# Evaluate diagnostic results
TOKEN_STATUS="❌ FAILED"
if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "ERROR: No users found" ]; then
    TOKEN_STATUS="✅ PASSED"
fi

VERIFY_STATUS="❌ CHECKED"
if [ ! -z "$VERIFY_RESPONSE" ] && [ "$VERIFY_RESPONSE" != "404" ]; then
    VERIFY_STATUS="✅ ACTIVE"
fi

SIIMUT_LOGS_STATUS="✅ CLEAN"
if [ ! -z "$SIIMUT_LOGS" ]; then
    SIIMUT_LOGS_STATUS="⚠️  ERRORS FOUND"
fi

IAM_LOGS_STATUS="✅ CLEAN"
if [ ! -z "$IAM_LOGS" ]; then
    IAM_LOGS_STATUS="⚠️  ERRORS FOUND"
fi

echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${NC}           🔍 DIAGNOSTIC RESULTS SUMMARY${NC}              ${YELLOW}║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}┌─ TEST RESULTS ─────────────────────────────────────────┐${NC}"
echo -e "│ Database Config        │ ⏱️  (See output #1)           │"
echo -e "│ Token Generation       │ $TOKEN_STATUS                              │"
echo -e "│ JWT Payload            │ ⏱️  (See output #3)           │"
echo -e "│ Verify Endpoint        │ $VERIFY_STATUS                              │"
echo -e "│ Session Configuration  │ ⏱️  (See output #5)           │"
echo -e "│ SIIMUT Logs            │ $SIIMUT_LOGS_STATUS                        │"
echo -e "│ IAM Logs               │ $IAM_LOGS_STATUS                          │"
echo -e "│ Nginx Redirects        │ ⏱️  (See output #10)          │"
echo -e "${YELLOW}└────────────────────────────────────────────────────────┘${NC}"
echo ""

echo -e "${YELLOW}┌─ CRITICAL CHECKS ──────────────────────────────────────┐${NC}"
if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "ERROR: No users found" ]; then
    echo -e "│ ✅ JWT Token Generated Successfully${NC}"
else
    echo -e "│ ❌ JWT Token Generation Failed - Check IAM database${NC}"
fi

if [ ! -z "$VERIFY_RESPONSE" ] && [ "$VERIFY_RESPONSE" != "404" ]; then
    echo -e "│ ✅ SIIMUT Verify Endpoint Responsive${NC}"
else
    echo -e "│ ❌ SIIMUT Verify Endpoint Not Responding${NC}"
fi

if [ -z "$SIIMUT_LOGS" ]; then
    echo -e "│ ✅ SIIMUT Logs Clean (No Errors)${NC}"
else
    echo -e "│ ⚠️  SIIMUT Logs Contain Warnings/Errors${NC}"
fi

if [ -z "$IAM_LOGS" ]; then
    echo -e "│ ✅ IAM Logs Clean (No Errors)${NC}"
else
    echo -e "│ ⚠️  IAM Logs Contain Warnings/Errors${NC}"
fi
echo -e "${YELLOW}└────────────────────────────────────────────────────────┘${NC}"
echo ""

echo -e "${YELLOW}┌─ NEXT STEPS ───────────────────────────────────────────┐${NC}"
echo -e "│ 1. Review output #1: Database redirect_uris config    │"
echo -e "│ 2. Review output #3: JWT payload structure & claims  │"
echo -e "│ 5. Verify session domains match between apps         │"
if [ ! -z "$SIIMUT_LOGS" ]; then
    echo -e "│ 8. Address SIIMUT log errors (output #8)            │"
fi
if [ ! -z "$IAM_LOGS" ]; then
    echo -e "│ 9. Address IAM log errors (output #9)               │"
fi
echo -e "│ 10. Check nginx redirect chain (output #10)          │"
echo -e "${YELLOW}└────────────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Diagnostic scan completed. Review outputs above carefully.${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
