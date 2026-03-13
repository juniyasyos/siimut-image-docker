#!/bin/bash

###############################################################################
#  Database Testing Script (DEBUG VERSION)
#  Menggunakan docker-compose.base.yml untuk testing database connections
###############################################################################

# JANGAN gunakan set -e agar script bisa continue saat ada error
# set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.base.yml"
DB_CONTAINER="database-service"
DB_HOST="db"
DB_ROOT_USER="root"
DB_ROOT_PASS="rootpass123"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Database Testing Script (DEBUG)${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to print section headers
print_section() {
    echo -e "\n${YELLOW}→ $1${NC}"
    echo "-------------------------------------------"
}

# Function to execute mysql command with error capture
run_mysql_cmd() {
    local user=$1
    local pass=$2
    local host=$3
    local database=$4
    local query=$5
    local output
    local exit_code
    
    if [ -z "$database" ]; then
        output=$(docker compose -f "$COMPOSE_FILE" exec -T db mysql -h "$host" -u "$user" -p"$pass" -e "$query" 2>&1)
        exit_code=$?
    else
        output=$(docker compose -f "$COMPOSE_FILE" exec -T db mysql -h "$host" -u "$user" -p"$pass" "$database" -e "$query" 2>&1)
        exit_code=$?
    fi
    
    if [ $exit_code -eq 0 ]; then
        echo "$output"
        return 0
    else
        echo -e "${RED}ERROR:${NC} $output"
        return 1
    fi
}

# ============================================================================
# Test 1: Check if database container is running
# ============================================================================
print_section "Test 1: Cek Status Container & Environment Variables"

if docker compose -f "$COMPOSE_FILE" ps | grep -q "database-service"; then
    echo -e "${GREEN}✓ Container '$DB_CONTAINER' sedang berjalan${NC}"
else
    echo -e "${RED}✗ Container '$DB_CONTAINER' TIDAK berjalan!${NC}"
    echo "   Jalankan: docker compose -f $COMPOSE_FILE up -d"
    exit 1
fi

# Check environment variables inside container
echo ""
echo "🔍 Environment variables dari container:"
echo "   MYSQL_ROOT_PASSWORD:"
docker compose -f "$COMPOSE_FILE" exec -T db bash -c 'echo "      Value: $MYSQL_ROOT_PASSWORD"' 2>/dev/null || echo "      (tidak bisa diakses)"

echo "   MYSQL_RANDOM_ROOT_PASSWORD:"
docker compose -f "$COMPOSE_FILE" exec -T db bash -c 'echo "      Value: $MYSQL_RANDOM_ROOT_PASSWORD"' 2>/dev/null || echo "      (tidak bisa diakses)"

# Check MySQL version
echo ""
echo "📊 MySQL version:"
docker compose -f "$COMPOSE_FILE" exec -T db mysql --version 2>/dev/null || echo "   (error)"

# ============================================================================
# Test 2: Wait for database to be ready
# ============================================================================
print_section "Test 2: Tunggu Database Ready (Health Check)"

echo "⏳ Waiting for database to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker compose -f "$COMPOSE_FILE" exec -T db mysqladmin ping -h localhost -u root -p"$DB_ROOT_PASS" --silent 2>/dev/null; then
        echo -e "${GREEN}✓ Database sudah ready!${NC}"
        break
    else
        attempt=$((attempt + 1))
        echo "   Attempt $attempt/$max_attempts..."
        sleep 2
    fi
done

if [ $attempt -eq $max_attempts ]; then
    echo -e "${RED}✗ Database tidak ready setelah ${max_attempts}x attempts${NC}"
fi

# ============================================================================
# Test 3: Test root access (verbose)
# ============================================================================
print_section "Test 3: Root Access Test - VERBOSE DEBUG"

echo "🔐 Mencoba koneksi dengan:"
echo "   Host: $DB_HOST"
echo "   User: $DB_ROOT_USER"
echo "   Pass: $DB_ROOT_PASS"
echo ""

if docker compose -f "$COMPOSE_FILE" exec -T db mysql -h "$DB_HOST" -u "$DB_ROOT_USER" -p"$DB_ROOT_PASS" -e "SELECT 'Connection OK' AS status;" 2>&1 | tee /tmp/mysql_test.log; then
    echo -e "${GREEN}✓ Root access BERHASIL!${NC}"
else
    echo -e "${RED}✗ Root access GAGAL!${NC}"
    echo -e "${MAGENTA}Debug Info:${NC}"
    cat /tmp/mysql_test.log
    echo ""
    echo "💡 Kemungkinan penyebab:"
    echo "   1. Password tidak sesuai dengan konfigurasi env/.env.db"
    echo "   2. Database belum fully initialized"
    echo "   3. my.cnf mengubah konfigurasi default"
    echo ""
    echo "🔧 Coba cara berikut:"
    echo "   docker compose -f $COMPOSE_FILE exec db bash"
    echo "   mysql -h localhost -u root --password='rootpass123' -e 'SHOW DATABASES;'"
    echo ""
    echo "   Atau cek env file:"
    echo "   cat env/.env.db"
fi

# ============================================================================
# Test 4: Show All Databases
# ============================================================================
print_section "Test 4: Daftar Semua Databases"

if run_mysql_cmd "$DB_ROOT_USER" "$DB_ROOT_PASS" "$DB_HOST" "" "SHOW DATABASES;"; then
    echo -e "${GREEN}✓ Query OK${NC}"
else
    echo -e "${YELLOW}⚠ Query failed${NC}"
fi

# ============================================================================
# Test 5: Show All Users
# ============================================================================
print_section "Test 5: Daftar Semua MySQL Users"

if run_mysql_cmd "$DB_ROOT_USER" "$DB_ROOT_PASS" "$DB_HOST" "mysql" "SELECT user, host FROM user;"; then
    echo -e "${GREEN}✓ Query OK${NC}"
else
    echo -e "${YELLOW}⚠ Query failed${NC}"
fi

# ============================================================================
# Test 6: Application Users Access
# ============================================================================
print_section "Test 6: SIIMUT User (siimut_user / siimut-password)"

if run_mysql_cmd "siimut_user" "siimut-password" "$DB_HOST" "siimut_db" "SELECT DATABASE() AS db, USER() AS user;" 2>/dev/null; then
    echo -e "${GREEN}✓ SIIMUT access OK${NC}"
else
    echo -e "${YELLOW}⚠ SIIMUT access failed${NC}"
fi

print_section "Test 7: IAM User (iam_user / iam-password)"

if run_mysql_cmd "iam_user" "iam-password" "$DB_HOST" "iam_db" "SELECT DATABASE() AS db, USER() AS user;" 2>/dev/null; then
    echo -e "${GREEN}✓ IAM access OK${NC}"
else
    echo -e "${YELLOW}⚠ IAM access failed${NC}"
fi

print_section "Test 8: IKP User (ikp_user / ikp-password)"

if run_mysql_cmd "ikp_user" "ikp-password" "$DB_HOST" "ikp_db" "SELECT DATABASE() AS db, USER() AS user;" 2>/dev/null; then
    echo -e "${GREEN}✓ IKP access OK${NC}"
else
    echo -e "${YELLOW}⚠ IKP access failed${NC}"
fi

# ============================================================================
# Test 9: Manual Debugging Commands
# ============================================================================
print_section "Test 9: Manual Commands untuk Debugging"

cat << 'EOF'
Jika root access gagal, coba ini:

1️⃣  Login ke container:
   docker compose -f docker-compose.base.yml exec db bash

2️⃣  Cek environment variables:
   env | grep MYSQL

3️⃣  Cek MySQL config:
   cat /etc/mysql/conf.d/my.cnf | grep -i password

4️⃣  Try manual MySQL connection:
   mysql -h localhost -u root -p'rootpass123' -e 'SELECT 1;'

5️⃣  Atau try tanpa password:
   mysql -h localhost -u root -e 'SELECT 1;'

6️⃣  Cek .env file:
   cat env/.env.db

7️⃣  Lihat full error:
   docker compose -f docker-compose.base.yml logs db | tail -50
EOF

print_section "SUMMARY - Credentials Reference"

cat << EOF
${MAGENTA}ROOT ACCESS:${NC}
   User: root
   Pass: rootpass123

${MAGENTA}APPLICATION DATABASES:${NC}
   1. siimut_db      → siimut_user / siimut-password
   2. iam_db         → iam_user / iam-password
   3. ikp_db         → ikp_user / ikp-password

${MAGENTA}READ-ONLY USERS:${NC}
   1. siimut_readonly / Siimut@ReadOnly2025!
   2. iam_readonly / Iam@ReadOnly2025!
   3. ikp_readonly / ikp@ReadOnly2025!

${YELLOW}⚠️  MASALAH ROOT PASSWORD:${NC}
   Jika root access gagal, kemungkinan:
   - Password beda di env/.env.db
   - database belum ready
   - my.cnf mengubah konfigurasi
EOF

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}✓ Testing Complete!${NC}"
echo -e "${BLUE}========================================${NC}\n"
