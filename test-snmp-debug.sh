#!/bin/bash

set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

NETWORK="monitoring-network"
PROM="prometheus"
SNMP="snmp-exporter"
PORT=9116
PROM_PORT=9990

# =========================
# Helper
# =========================
pass(){ echo -e "${GREEN}✔ $1${NC}"; ((PASS++)); }
fail(){ echo -e "${RED}✖ $1${NC}"; ((FAIL++)); }
warn(){ echo -e "${YELLOW}⚠ $1${NC}"; ((WARN++)); }
section(){ echo -e "\n${BLUE}=== $1 ===${NC}"; }

# =========================
# Dependency Check
# =========================
section "DEPENDENCY CHECK"

for cmd in docker curl ss jq; do
    command -v $cmd >/dev/null 2>&1 \
        && pass "$cmd installed" \
        || fail "$cmd missing"
done

# =========================
# Network Layer
# =========================
section "NETWORK"

docker network inspect $NETWORK >/dev/null 2>&1 \
    && pass "Docker network OK" \
    || fail "Docker network missing"

# =========================
# Container Layer
# =========================
section "CONTAINER"

for c in $PROM $SNMP; do
    if docker ps --format '{{.Names}}' | grep -q "^$c$"; then
        pass "$c running"
    else
        fail "$c NOT running"
    fi
done

# =========================
# Port Layer (CRITICAL)
# =========================
section "PORT ANALYSIS"

PORT_INFO=$(sudo ss -tulnp | grep ":$PORT")

if [ -z "$PORT_INFO" ]; then
    fail "Port $PORT not used"
else
    OWNER=$(echo "$PORT_INFO" | grep -oP 'users:\(\("\K[^"]+')
    echo "→ $PORT_INFO"

    if echo "$PORT_INFO" | grep -q "docker"; then
        pass "Port owned by docker"
    elif [ "$OWNER" = "snmp_exporter" ]; then
        warn "snmp_exporter running on HOST"
    else
        warn "Unknown process using port ($OWNER)"
    fi
fi

# =========================
# Process Deep Inspect
# =========================
section "PROCESS INSPECT"

PID=$(echo "$PORT_INFO" | grep -oP 'pid=\K[0-9]+')

if [ -n "$PID" ]; then
    ps -fp $PID
    readlink -f /proc/$PID/exe
    pass "Process inspected"
else
    warn "No PID found"
fi

# =========================
# Docker Binding
# =========================
section "DOCKER PORT BIND"

docker ps | grep -q "$PORT" \
    && pass "Docker expose port $PORT" \
    || fail "Docker NOT exposing $PORT"

# =========================
# DNS Resolution
# =========================
section "DNS TEST (PROM → SNMP)"

docker exec $PROM getent hosts $SNMP >/dev/null 2>&1 \
    && pass "DNS resolve OK" \
    || fail "DNS resolve FAIL"

# =========================
# Network Connectivity
# =========================
section "NETWORK CONNECTIVITY"

docker exec $PROM ping -c1 $SNMP >/dev/null 2>&1 \
    && pass "Ping OK" \
    || fail "Ping FAIL"

# =========================
# HTTP Layer
# =========================
section "HTTP CHECK"

LATENCY=$(curl -o /dev/null -s -w '%{time_total}' http://localhost:$PORT/metrics)

if [ $? -eq 0 ]; then
    pass "HTTP OK (${LATENCY}s)"
else
    fail "HTTP FAIL"
fi

# =========================
# Prometheus API
# =========================
section "PROMETHEUS API"

TARGET=$(curl -s http://localhost:$PROM_PORT/api/v1/targets)

if echo "$TARGET" | jq -e . >/dev/null 2>&1; then
    pass "Prom API reachable"
else
    fail "Prom API broken"
fi

# =========================
# Metrics Validation
# =========================
section "METRICS VALIDATION"

echo "$TARGET" | grep -q '"health":"up"' \
    && pass "Targets UP" \
    || fail "Targets DOWN"

# =========================
# Conflict Detection
# =========================
section "CONFLICT DETECTION"

if [ "$OWNER" = "snmp_exporter" ] && docker ps | grep -q "$SNMP"; then
    fail "DOUBLE INSTANCE (host + docker)"
elif [ "$OWNER" = "snmp_exporter" ]; then
    warn "Running outside docker"
fi

# =========================
# SUMMARY
# =========================
section "SUMMARY"

TOTAL=$((PASS+FAIL+WARN))

echo -e "✔ PASS : $PASS"
echo -e "✖ FAIL : $FAIL"
echo -e "⚠ WARN : $WARN"
echo -e "TOTAL  : $TOTAL"

# =========================
# ROOT CAUSE ENGINE
# =========================
section "AUTO DIAGNOSIS"

if [ $FAIL -eq 0 ] && [ $WARN -eq 0 ]; then
    echo -e "${GREEN}System NORMAL${NC}"

elif [ "$OWNER" = "snmp_exporter" ]; then
    echo -e "${YELLOW}ROOT CAUSE:${NC}"
    echo "Host-based SNMP exporter (bukan Docker)"
    echo "→ menyebabkan port conflict & monitoring ambiguity"

    echo -e "\nFIX:"
    echo "sudo kill -9 $PID"

elif [ $FAIL -ge 3 ]; then
    echo -e "${RED}ROOT CAUSE:${NC}"
    echo "Broken monitoring stack (network/DNS/container)"

    echo -e "\nFIX:"
    echo "docker compose down -v"
    echo "docker network rm $NETWORK"
    echo "docker compose up -d"

else
    echo -e "${YELLOW}Minor issues detected${NC}"
fi

echo -e "\nDone.\n"