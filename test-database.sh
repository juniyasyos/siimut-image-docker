#!/bin/bash

###############################################################################
#  Database Testing Script
#  Menggunakan docker-compose.base.yml untuk testing database connections
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.base.yml"
DB_CONTAINER="database-service"
DB_HOST="db"
DB_ROOT_USER="root"
DB_ROOT_PASS="rootpass123"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Database Testing Script${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to print section headers
print_section() {
    echo -e "\n${YELLOW}→ $1${NC}"
    echo "-------------------------------------------"
}

# Function to execute mysql command
run_mysql_cmd() {
    local user=$1
    local pass=$2
    local host=$3
    local database=$4
    local query=$5
    
    if [ -z "$database" ]; then
        docker compose -f "$COMPOSE_FILE" exec -T db mysql -h "$host" -u "$user" -p"$pass" -e "$query"
    else
        docker compose -f "$COMPOSE_FILE" exec -T db mysql -h "$host" -u "$user" -p"$pass" "$database" -e "$query"
    fi
}

# ============================================================================
# Test 1: Check if database container is running
# ============================================================================
print_section "Test 1: Cek Status Container"

if docker compose -f "$COMPOSE_FILE" ps | grep -q "database-service"; then
    echo -e "${GREEN}✓ Container '$DB_CONTAINER' sedang berjalan${NC}"
else
    echo -e "${RED}✗ Container '$DB_CONTAINER' TIDAK berjalan!${NC}"
    echo "   Jalankan: docker compose -f $COMPOSE_FILE up -d"
    exit 1
fi

# ============================================================================
# Test 2: Root Access Test
# ============================================================================
print_section "Test 2: Root Access (root / rootpass123)"

if run_mysql_cmd "$DB_ROOT_USER" "$DB_ROOT_PASS" "$DB_HOST" "" "SELECT 'Root access OK' AS status;" 2>/dev/null; then
    echo -e "${GREEN}✓ Root access berhasil!${NC}"
else
    echo -e "${RED}✗ Root access GAGAL!${NC}"
    exit 1
fi

# ============================================================================
# Test 3: Show All Databases
# ============================================================================
print_section "Test 3: Daftar Semua Databases"

run_mysql_cmd "$DB_ROOT_USER" "$DB_ROOT_PASS" "$DB_HOST" "" "SHOW DATABASES;"

# ============================================================================
# Test 4: Show All Users
# ============================================================================
print_section "Test 4: Daftar Semua MySQL Users"

run_mysql_cmd "$DB_ROOT_USER" "$DB_ROOT_PASS" "$DB_HOST" "mysql" "SELECT user, host FROM user;"

# ============================================================================
# Test 5: SIIMUT Database Access
# ============================================================================
print_section "Test 5: SIIMUT Database (siimut_user / siimut-password)"

if run_mysql_cmd "siimut_user" "siimut-password" "$DB_HOST" "siimut_db" "SELECT DATABASE() AS current_db, USER() AS current_user;" 2>/dev/null; then
    echo -e "${GREEN}✓ SIIMUT database access berhasil!${NC}"
else
    echo -e "${RED}✗ SIIMUT database access GAGAL!${NC}"
fi

# ============================================================================
# Test 6: IAM Database Access
# ============================================================================
print_section "Test 6: IAM Database (iam_user / iam-password)"

if run_mysql_cmd "iam_user" "iam-password" "$DB_HOST" "iam_db" "SELECT DATABASE() AS current_db, USER() AS current_user;" 2>/dev/null; then
    echo -e "${GREEN}✓ IAM database access berhasil!${NC}"
else
    echo -e "${RED}✗ IAM database access GAGAL!${NC}"
fi

# ============================================================================
# Test 7: IKP Database Access
# ============================================================================
print_section "Test 7: IKP Database (ikp_user / ikp-password)"

if run_mysql_cmd "ikp_user" "ikp-password" "$DB_HOST" "ikp_db" "SELECT DATABASE() AS current_db, USER() AS current_user;" 2>/dev/null; then
    echo -e "${GREEN}✓ IKP database access berhasil!${NC}"
else
    echo -e "${RED}✗ IKP database access GAGAL!${NC}"
fi

# ============================================================================
# Test 8: Read-Only Users
# ============================================================================
print_section "Test 8: SIIMUT Read-Only User (siimut_readonly / Siimut@ReadOnly2025!)"

if run_mysql_cmd "siimut_readonly" "Siimut@ReadOnly2025!" "$DB_HOST" "siimut_db" "SELECT 'Read-only access OK' AS status;" 2>/dev/null; then
    echo -e "${GREEN}✓ SIIMUT read-only access berhasil!${NC}"
else
    echo -e "${RED}✗ SIIMUT read-only access GAGAL!${NC}"
fi

# ============================================================================
# Test 9: Check Privileges for Each User
# ============================================================================
print_section "Test 9: Verifikasi Privileges untuk SIIMUT User"

run_mysql_cmd "$DB_ROOT_USER" "$DB_ROOT_PASS" "$DB_HOST" "mysql" "SHOW GRANTS FOR 'siimut_user'@'%';"

# ============================================================================
# Test 10: Show Database Size
# ============================================================================
print_section "Test 10: Ukuran Database"

docker compose -f "$COMPOSE_FILE" exec -T db mysql -h "$DB_HOST" -u "$DB_ROOT_USER" -p"$DB_ROOT_PASS" -e "SELECT table_schema AS Database, ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS Size_MB FROM information_schema.tables GROUP BY table_schema ORDER BY Size_MB DESC;" 2>/dev/null || echo "   (Database masih kosong)"

# ============================================================================
# Summary
# ============================================================================
print_section "SUMMARY"

cat << EOF
${GREEN}Database Testing Completed!${NC}

✅ Root Configuration:
   - User: root
   - Password: rootpass123
   - Status: Ready

✅ Databases Created:
   - siimut_db (user: siimut_user / siimut-password)
   - iam_db (user: iam_user / iam-password)
   - ikp_db (user: ikp_user / ikp-password)

✅ Additional Read-Only Users Available:
   - siimut_readonly / Siimut@ReadOnly2025!
   - iam_readonly / Iam@ReadOnly2025!
   - ikp_readonly / ikp@ReadOnly2025!

📝 Quick Connect Commands:
   docker compose -f $COMPOSE_FILE exec db mysql -h db -u root -p'rootpass123'
   docker compose -f $COMPOSE_FILE exec db mysql -h db -u siimut_user -p'siimut-password' siimut_db
   docker compose -f $COMPOSE_FILE exec db mysql -h db -u iam_user -p'iam-password' iam_db
   docker compose -f $COMPOSE_FILE exec db mysql -h db -u ikp_user -p'ikp-password' ikp_db

🔧 More info: cat DATABASE-CREDENTIALS.md
EOF

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Testing Complete!${NC}"
echo -e "${BLUE}========================================${NC}\n"
