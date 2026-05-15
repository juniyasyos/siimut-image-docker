#!/bin/bash

####################################################################################################
# Test Script: Debug SNMP Exporter + Prometheus Network & DNS Issues
# Usage: bash test-snmp-debug.sh
####################################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

echo_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

echo_error() {
    echo -e "${RED}✗ $1${NC}"
}

echo_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

echo_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

####################################################################################################
# TEST 1: Check Docker Networks
####################################################################################################
echo_header "TEST 1: Check Docker Networks"

NETWORK_NAME="monitoring-network"
if docker network ls | grep -q "$NETWORK_NAME"; then
    echo_success "Network '$NETWORK_NAME' exists"
else
    echo_error "Network '$NETWORK_NAME' NOT found"
    exit 1
fi

####################################################################################################
# TEST 2: Check Containers Status
####################################################################################################
echo_header "TEST 2: Check Containers Status"

echo_info "Running Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Networks}}"

# Check specific containers
for container in prometheus grafana snmp-exporter; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        STATUS=$(docker inspect "$container" --format='{{.State.Status}}')
        echo_success "Container '$container' is $STATUS"
    else
        echo_warning "Container '$container' is NOT running"
    fi
done

####################################################################################################
# TEST 3: Inspect Shared Network
####################################################################################################
echo_header "TEST 3: Inspect Shared Network"

echo_info "Containers connected to '$NETWORK_NAME':"
docker network inspect "$NETWORK_NAME" | grep -E '"Name"|"IPv4Address"' | head -20

echo_info "Network Details:"
docker network inspect "$NETWORK_NAME" --format='{{.Driver}} | {{.Scope}} | IPAM Pool: {{.IPAM.Config}}'

####################################################################################################
# TEST 4: DNS Resolution from Prometheus
####################################################################################################
echo_header "TEST 4: DNS Resolution from Prometheus"

if ! docker ps --format '{{.Names}}' | grep -q "^prometheus$"; then
    echo_error "Prometheus container NOT running - skipping DNS tests"
else
    echo_info "Testing DNS from prometheus container:"
    
    # Test ping snmp-exporter
    echo_info "Command: docker exec prometheus ping -c 3 snmp-exporter"
    if docker exec prometheus ping -c 3 snmp-exporter > /dev/null 2>&1; then
        echo_success "PING snmp-exporter: SUCCESS"
    else
        echo_error "PING snmp-exporter: FAILED (bad address or unreachable)"
        echo_warning "This is the root cause - DNS not resolving inside prometheus container"
    fi
    
    # Test nslookup
    echo_info "Command: docker exec prometheus nslookup snmp-exporter"
    if docker exec prometheus nslookup snmp-exporter > /dev/null 2>&1; then
        echo_success "NSLOOKUP snmp-exporter: SUCCESS"
        docker exec prometheus nslookup snmp-exporter
    else
        echo_error "NSLOOKUP snmp-exporter: FAILED"
    fi
    
    # Test wget
    echo_info "Command: docker exec prometheus wget -qO- http://snmp-exporter:9116/metrics (first 10 lines)"
    if docker exec prometheus wget -qO- http://snmp-exporter:9116/metrics 2>/dev/null | head -n 10; then
        echo_success "WGET http://snmp-exporter:9116/metrics: SUCCESS"
    else
        echo_error "WGET http://snmp-exporter:9116/metrics: FAILED"
    fi
fi

####################################################################################################
# TEST 5: Test SNMP Exporter Endpoint (from host)
####################################################################################################
echo_header "TEST 5: Test SNMP Exporter Endpoint (from Host)"

SNMP_PORT="9116"
if docker ps --format '{{.Names}}' | grep -q "^snmp-exporter$"; then
    echo_info "Testing SNMP exporter on localhost:$SNMP_PORT"
    
    # Test metrics endpoint
    echo_info "Command: curl -s http://localhost:$SNMP_PORT/metrics | head -n 10"
    if curl -s "http://localhost:$SNMP_PORT/metrics" 2>/dev/null | head -n 10; then
        echo_success "METRICS endpoint: SUCCESS"
    else
        echo_error "METRICS endpoint: FAILED (check if port 9116 is open)"
    fi
    
    # Test SNMP query endpoint
    echo_info "Command: curl -s http://localhost:$SNMP_PORT/snmp?target=192.168.1.1&module=mikrotik&auth=public_v2 (first 10 lines)"
    if curl -s "http://localhost:$SNMP_PORT/snmp?target=192.168.1.1&module=mikrotik&auth=public_v2" 2>/dev/null | head -n 10; then
        echo_success "SNMP query endpoint: SUCCESS"
    else
        echo_warning "SNMP query endpoint: May fail if target 192.168.1.1 is not reachable"
    fi
else
    echo_error "SNMP Exporter container NOT running"
fi

####################################################################################################
# TEST 6: Check Prometheus Targets
####################################################################################################
echo_header "TEST 6: Check Prometheus Targets Status"

PROM_PORT="9990"
echo_info "Command: curl -s http://localhost:$PROM_PORT/api/v1/targets"

TARGETS=$(curl -s "http://localhost:$PROM_PORT/api/v1/targets" 2>/dev/null)

if [ -z "$TARGETS" ] || [ "$TARGETS" = "{}" ]; then
    echo_error "Could not fetch targets from Prometheus (is it running on port $PROM_PORT?)"
else
    echo_info "Active Targets:"
    echo "$TARGETS" | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health, lastError: .lastError}' 2>/dev/null || echo_error "jq not installed, raw output:"
    echo "$TARGETS" | grep -o '"job":"[^"]*"' | head -10
    
    # Highlight snmp-mikrotik job
    echo_info "SNMP Mikrotik Target Status:"
    echo "$TARGETS" | jq '.data.activeTargets[] | select(.labels.job == "snmp-mikrotik")' 2>/dev/null || echo_warning "No snmp-mikrotik target found"
fi

####################################################################################################
# TEST 7: Reload Prometheus Config
####################################################################################################
echo_header "TEST 7: Reload Prometheus Config"

echo_info "Command: curl -X POST http://localhost:$PROM_PORT/-/reload"
if curl -s -X POST "http://localhost:$PROM_PORT/-/reload" > /dev/null 2>&1; then
    sleep 2
    if curl -s "http://localhost:$PROM_PORT/-/healthy" 2>/dev/null | grep -q "Prometheus"; then
        echo_success "Prometheus config RELOADED successfully"
    else
        echo_error "Prometheus not healthy after reload"
    fi
else
    echo_error "Failed to reload Prometheus config"
fi

####################################################################################################
# TEST 8: Query Prometheus Metrics
####################################################################################################
echo_header "TEST 8: Query Prometheus SNMP Metrics"

echo_info "Query 1: hrSystemUptime"
QUERY1=$(curl -s "http://localhost:$PROM_PORT/api/v1/query?query=hrSystemUptime" 2>/dev/null)
if echo "$QUERY1" | jq -e '.data.result[] | .value' > /dev/null 2>/dev/null; then
    echo_success "hrSystemUptime query returned data:"
    echo "$QUERY1" | jq '.data.result[]' 2>/dev/null | head -n 5
else
    echo_warning "hrSystemUptime query returned no data (may be expected if device unreachable)"
fi

echo_info "Query 2: node_up (from node-exporter)"
QUERY2=$(curl -s "http://localhost:$PROM_PORT/api/v1/query?query=node_up" 2>/dev/null)
if echo "$QUERY2" | jq -e '.data.result[] | .value' > /dev/null 2>/dev/null; then
    echo_success "node_up query returned data"
else
    echo_warning "node_up query returned no data (check if node-exporter is configured)"
fi

####################################################################################################
# TEST 9: Check SNMP Exporter Logs
####################################################################################################
echo_header "TEST 9: SNMP Exporter Logs (last 20 lines)"

if docker ps --format '{{.Names}}' | grep -q "^snmp-exporter$"; then
    docker logs --tail=20 snmp-exporter
else
    echo_warning "SNMP Exporter not running"
fi

####################################################################################################
# TEST 10: Check Prometheus Logs
####################################################################################################
echo_header "TEST 10: Prometheus Logs (last 20 lines)"

if docker ps --format '{{.Names}}' | grep -q "^prometheus$"; then
    docker logs --tail=20 prometheus
else
    echo_warning "Prometheus not running"
fi

####################################################################################################
# SUMMARY & RECOMMENDATIONS
####################################################################################################
echo_header "SUMMARY & RECOMMENDATIONS"

echo_info "If DNS resolution failed (Step 4):"
echo "  1. Stop both compose stacks: docker compose -f docker-compose-monitoring.yml down && docker compose -f docker-compose-snmp-exporter.yml down"
echo "  2. Remove network: docker network rm monitoring-network"
echo "  3. Restart monitoring stack: docker compose -f docker-compose-monitoring.yml up -d"
echo "  4. Restart SNMP exporter: docker compose -f docker-compose-snmp-exporter.yml up -d"
echo "  5. Re-run this test script"

echo_info "If SNMP query failed (Step 5):"
echo "  1. Verify SNMP target IPs are reachable from container:"
echo "     docker exec snmp-exporter ping -c 3 192.168.1.1"
echo "  2. Verify SNMP community string in prometheus.yml matches your Mikrotik device"
echo "  3. Check if SNMP service is enabled on Mikrotik (IP > Services > SNMP)"

echo_info "If Prometheus targets show DOWN (Step 6):"
echo "  1. Check logs: docker logs prometheus"
echo "  2. Check target reachability from prometheus container"
echo "  3. Reload config: curl -X POST http://localhost:9990/-/reload"

echo_info "For Grafana dashboard issues:"
echo "  1. Ensure Prometheus data source is correctly configured (http://prometheus:9090)"
echo "  2. Verify dashboard queries match available metrics from SNMP exporter"
echo "  3. Check Grafana logs: docker logs grafana"

echo_success "Test script completed!"
