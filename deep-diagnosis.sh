#!/bin/bash

echo "=========================================="
echo "COMPREHENSIVE LOGIN FLOW DIAGNOSTICS"
echo "=========================================="
echo "Timestamp: $(date)"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============== OUTPUT #1: DATABASE CONFIG ==============
echo -e "${YELLOW}=== OUTPUT #1: DATABASE - APPLICATIONS TABLE ===${NC}"
echo "Query: SELECT id, key, name, redirect_uris FROM applications WHERE key='siimut'"
echo ""
DB_RESULT=$(docker compose -f docker-compose-multi-apps.yml exec -T database-service mysql -u iam_user -piam-password iam_db -e \
"SELECT id, key, name, redirect_uris FROM applications WHERE key='siimut';" 2>&1)
echo "$DB_RESULT"
echo ""

# Extract redirect_uris for later comparison
REDIRECT_URIS=$(echo "$DB_RESULT" | tail -1 | awk '{print $NF}')
echo -e "${BLUE}Extracted redirect_uris: $REDIRECT_URIS${NC}"
echo ""

# ============== OUTPUT #2: TOKEN GENERATION ==============
echo -e "${YELLOW}=== OUTPUT #2: GENERATE JWT TOKEN FROM IAM ===${NC}"
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

if [ "$TOKEN" = "ERROR: No users found" ]; then
    echo -e "${RED}❌ No users in IAM database${NC}"
else
    echo -e "${GREEN}✅ Token generated (first 80 chars):${NC}"
    echo "${TOKEN:0:80}..."
fi
echo ""

# ============== OUTPUT #3: JWT PAYLOAD DECODE ==============
echo -e "${YELLOW}=== OUTPUT #3: DECODE JWT PAYLOAD ===${NC}"
if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "ERROR: No users found" ]; then
    IFS='.' read -r HEADER PAYLOAD FOOTER <<< "$TOKEN"
    PAYLOAD_PADDED="${PAYLOAD}$(printf '%*s' $(( (4 - ${#PAYLOAD} % 4) % 4 )) | tr ' ' '=')"
    DECODED=$(echo "$PAYLOAD_PADDED" | base64 -d 2>/dev/null)
    
    echo "Raw JWT Token:"
    echo "  Header: ${HEADER:0:40}..."
    echo "  Payload: ${PAYLOAD:0:40}..."
    echo "  Signature: ${FOOTER:0:40}..."
    echo ""
    echo "Decoded Payload JSON:"
    echo "$DECODED" | jq '.' 2>/dev/null || echo "$DECODED"
else
    echo -e "${RED}❌ Cannot decode - no valid token${NC}"
fi
echo ""

# ============== OUTPUT #4: CORS HEADERS CHECK ==============
echo -e "${YELLOW}=== OUTPUT #4: CORS HEADERS CHECK ===${NC}"
echo "Testing CORS headers from IAM server..."
echo "Request: OPTIONS http://192.168.1.9:8100/api/sso/admin/auth-code"
CORS_RESPONSE=$(curl -s -i -X OPTIONS \
    -H "Origin: http://192.168.1.9:8000" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: content-type" \
    http://192.168.1.9:8100/api/sso/admin/auth-code 2>&1)

echo "$CORS_RESPONSE" | head -20
echo ""

# Check for CORS headers
if echo "$CORS_RESPONSE" | grep -i "access-control-allow"; then
    echo -e "${GREEN}✅ CORS headers present${NC}"
else
    echo -e "${RED}❌ CORS headers MISSING - May cause browser to reject requests${NC}"
fi
echo ""

# ============== OUTPUT #5: SESSION CONFIGURATION ==============
echo -e "${YELLOW}=== OUTPUT #5: SESSION CONFIGURATION COMPARISON ===${NC}"
echo "SIIMUT Session Config:"
SIIMUT_SESSION=$(docker compose -f docker-compose-multi-apps.yml exec -T app-siimut php -r "
require 'vendor/autoload.php';
\$app = require 'bootstrap/app.php';
\$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

echo 'Driver: ' . config('session.driver') . PHP_EOL;
echo 'Domain: ' . (config('session.domain') ?: '(null)') . PHP_EOL;
echo 'Lifetime: ' . config('session.lifetime') . ' minutes' . PHP_EOL;
echo 'Cookie Secure: ' . (config('session.secure') ? 'true' : 'false') . PHP_EOL;
echo 'Cookie HttpOnly: ' . (config('session.http_only') ? 'true' : 'false') . PHP_EOL;
echo 'Same Site: ' . (config('session.same_site') ?: 'default') . PHP_EOL;
" 2>&1)
echo "$SIIMUT_SESSION"
echo ""

echo "IAM Session Config:"
IAM_SESSION=$(docker compose -f docker-compose-multi-apps.yml exec -T app-iam php -r "
require 'vendor/autoload.php';
\$app = require 'bootstrap/app.php';
\$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

echo 'Driver: ' . config('session.driver') . PHP_EOL;
echo 'Domain: ' . (config('session.domain') ?: '(null)') . PHP_EOL;
echo 'Lifetime: ' . config('session.lifetime') . ' minutes' . PHP_EOL;
echo 'Cookie Secure: ' . (config('session.secure') ? 'true' : 'false') . PHP_EOL;
echo 'Cookie HttpOnly: ' . (config('session.http_only') ? 'true' : 'false') . PHP_EOL;
echo 'Same Site: ' . (config('session.same_site') ?: 'default') . PHP_EOL;
" 2>&1)
echo "$IAM_SESSION"
echo ""

# ============== OUTPUT #6: TEST LOGIN PAGE ==============
echo -e "${YELLOW}=== OUTPUT #6: TEST SIIMUT LOGIN PAGE REQUEST ===${NC}"
echo "Request: GET http://192.168.1.9:8000/siimut/login"
echo "Following max 2 redirects to see redirect chain..."
echo ""
LOGIN_RESPONSE=$(curl -s -i -L --max-redirs 2 http://192.168.1.9:8000/siimut/login 2>&1)
echo "$LOGIN_RESPONSE" | head -80
echo ""

# Extract Location headers to show redirect chain
echo "Redirect chain detected:"
echo "$LOGIN_RESPONSE" | grep -i "^location:" || echo "No redirects found"
echo ""

# ============== OUTPUT #7: VERIFY ENDPOINT TEST ==============
echo -e "${YELLOW}=== OUTPUT #7: TEST SIIMUT VERIFY ENDPOINT ===${NC}"
if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "ERROR: No users found" ]; then
    echo "Testing with real JWT token..."
    echo "Request: GET http://192.168.1.9:8000/api/sso/verify"
    echo "Authorization: Bearer [JWT token]"
    echo ""
    VERIFY_RESPONSE=$(curl -s -i -H "Authorization: Bearer $TOKEN" \
        http://192.168.1.9:8000/api/sso/verify 2>&1)
    
    echo "Response (first 50 lines):"
    echo "$VERIFY_RESPONSE" | head -50
else
    echo -e "${RED}❌ Skipped - no token available${NC}"
fi
echo ""

# ============== OUTPUT #8: SIIMUT LOGS ==============
echo -e "${YELLOW}=== OUTPUT #8: SIIMUT CONTAINER LOGS (last 80 lines) ===${NC}"
docker compose -f docker-compose-multi-apps.yml logs app-siimut --tail=80 2>&1
echo ""

# ============== OUTPUT #9: IAM LOGS ==============
echo -e "${YELLOW}=== OUTPUT #9: IAM CONTAINER LOGS (last 80 lines) ===${NC}"
docker compose -f docker-compose-multi-apps.yml logs app-iam --tail=80 2>&1
echo ""

# ============== OUTPUT #10: NGINX LOGS ==============
echo -e "${YELLOW}=== OUTPUT #10: NGINX LOGS (last 80 lines) ===${NC}"
docker compose -f docker-compose-multi-apps.yml logs web --tail=80 2>&1
echo ""

# ============== COMPREHENSIVE ANALYSIS ==============
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${NC}        🔍 COMPREHENSIVE ROOT CAUSE ANALYSIS${NC}             ${YELLOW}║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Analysis 1: Redirect URI Mismatch
echo -e "${BLUE}[CHECK 1] Redirect URI Configuration${NC}"
if echo "$DB_RESULT" | grep -q "http://192.168.1.9:8000\|http://192.168.1.9:8000"; then
    echo -e "${GREEN}✅ redirect_uris in database looks correct${NC}"
    echo "   Actual value: $REDIRECT_URIS"
else
    echo -e "${RED}❌ ISSUE: redirect_uris may be incorrect${NC}"
    echo "   Database shows: $REDIRECT_URIS"
    echo "   Expected: http://192.168.1.9:8000 or http://192.168.1.9:8000"
fi
echo ""

# Analysis 2: Token Generation
echo -e "${BLUE}[CHECK 2] JWT Token Generation${NC}"
if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "ERROR: No users found" ]; then
    echo -e "${GREEN}✅ Token generation successful${NC}"
    echo "   Token format: JWT (3 parts separated by dots)"
else
    echo -e "${RED}❌ ISSUE: Cannot generate JWT token${NC}"
    echo "   Possible causes:"
    echo "   - No users in IAM database"
    echo "   - JWT_SECRET not configured"
    echo "   - Database connection issue"
fi
echo ""

# Analysis 3: CORS Headers
echo -e "${BLUE}[CHECK 3] CORS Configuration${NC}"
if echo "$CORS_RESPONSE" | grep -qi "access-control-allow-origin"; then
    echo -e "${GREEN}✅ CORS headers configured${NC}"
else
    echo -e "${RED}❌ ISSUE: CORS headers missing${NC}"
    echo "   Browser will block cross-origin requests from SIIMUT (8000) to IAM (8100)"
    echo "   Solution: Add CORS middleware to IAM routes"
fi
echo ""

# Analysis 4: Redirect Loop Detection
echo -e "${BLUE}[CHECK 4] Redirect Loop Indicators${NC}"
if echo "$LOGIN_RESPONSE" | grep -i "location:" | tail -1 | grep -q "siimut/login"; then
    echo -e "${RED}❌ LOOP DETECTED: Final redirect points back to /siimut/login${NC}"
    echo "   This indicates session validation is failing"
    echo "   Probable causes:"
    echo "   - Token not being stored in session"
    echo "   - Session domain mismatch"
    echo "   - CSRF token issue"
elif echo "$LOGIN_RESPONSE" | grep -q "Set-Cookie"; then
    echo -e "${GREEN}✅ Session cookies being set${NC}"
else
    echo -e "${YELLOW}⚠️  No session cookies detected${NC}"
fi
echo ""

# Analysis 5: Session Domain Matching
echo -e "${BLUE}[CHECK 5] Session Domain Compatibility${NC}"
SIIMUT_DOMAIN=$(echo "$SIIMUT_SESSION" | grep "Domain:" | awk '{print $NF}')
IAM_DOMAIN=$(echo "$IAM_SESSION" | grep "Domain:" | awk '{print $NF}')
echo "SIIMUT Domain: ${SIIMUT_DOMAIN:-(null)}"
echo "IAM Domain: ${IAM_DOMAIN:-(null)}"

if [ "$SIIMUT_DOMAIN" != "$IAM_DOMAIN" ]; then
    if [ -z "$SIIMUT_DOMAIN" ] && [ -z "$IAM_DOMAIN" ]; then
        echo -e "${GREEN}✅ Both using null domain (acceptable for localhost)${NC}"
    else
        echo -e "${YELLOW}⚠️  Domains don't match - may cause session issues${NC}"
    fi
else
    echo -e "${GREEN}✅ Domains match${NC}"
fi
echo ""

# Analysis 6: Verify Endpoint Response
echo -e "${BLUE}[CHECK 6] Token Verification${NC}"
if echo "$VERIFY_RESPONSE" | grep -q "200\|verified\|success"; then
    echo -e "${GREEN}✅ Verify endpoint accepts token${NC}"
elif echo "$VERIFY_RESPONSE" | grep -q "401\|403\|unauthorized"; then
    echo -e "${RED}❌ ISSUE: Verify endpoint rejecting token${NC}"
    echo "   Possible causes:"
    echo "   - Token signature invalid"
    echo "   - Token expired"
    echo "   - JWT_SECRET mismatch between IAM and SIIMUT"
elif echo "$VERIFY_RESPONSE" | grep -q "404"; then
    echo -e "${RED}❌ ISSUE: Verify endpoint not found (404)${NC}"
    echo "   Check if /api/sso/verify route exists in SIIMUT"
else
    echo -e "${YELLOW}⚠️  Unexpected response - check output #7${NC}"
fi
echo ""

# Final recommendation
echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${NC}                      RECOMMENDATIONS${NC}                       ${YELLOW}║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "1. Check OUTPUT #1 - Verify redirect_uris in database is correct"
echo "2. Check OUTPUT #3 - Verify JWT payload contains all required claims (sub, iss, iat, exp)"
echo "3. Check OUTPUT #4 - If CORS missing, add CorsServiceProvider to SIIMUT"
echo "4. Check OUTPUT #6 - If redirect loop detected, investigate SESSION storage"
echo "5. Check OUTPUT #8 & #9 - Look for specific error messages in application logs"
echo "6. Check OUTPUT #10 - Review nginx error logs for any routing issues"
echo ""
echo "Most Common Causes of Login Loop:"
echo "  • CORS headers missing → browser blocks SSO requests"
echo "  • Session domain mismatch → session not shared between apps"
echo "  • Redirect URI mismatch → OAuth callback fails"
echo "  • Token verification fails → session invalidated immediately"
echo ""

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Diagnostic scan completed. Review outputs above carefully.${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
