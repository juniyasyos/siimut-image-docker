#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_MONITORING="$SCRIPT_DIR/docker-compose-monitoring.yml"
COMPOSE_NODE_EXPORTER="$SCRIPT_DIR/docker-compose-node-exporter.yml"
PROMETHEUS_CONFIG="$SCRIPT_DIR/monitoring/prometheus.yml"
BACKUP_SUFFIX="$(date +%Y%m%d_%H%M%S)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_help() {
    cat <<'EOF'
Usage:
  ./setup-monitoring.sh monitoring <target-server-ip>
  ./setup-monitoring.sh target-server <monitoring-server-ip>

Examples:
  ./setup-monitoring.sh monitoring 192.168.1.100
  ./setup-monitoring.sh target-server 192.168.1.200

Roles:
  monitoring     Update Prometheus target IP and start Prometheus + Grafana.
  target-server  Start Node Exporter on the production/target server.
EOF
}

detect_compose_cmd() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        return 1
    fi
}

validate_ip() {
    local ip="$1"

    if [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
        for octet in "$o1" "$o2" "$o3" "$o4"; do
            if [[ "$octet" -lt 0 || "$octet" -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi

    if [[ "$ip" =~ ^[A-Za-z0-9.-]+$ ]]; then
        return 0
    fi

    return 1
}

require_file() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        log_error "File tidak ditemukan: $file_path"
        exit 1
    fi
}

update_prometheus_target() {
    local target_ip="$1"
    local backup_file="${PROMETHEUS_CONFIG}.backup.${BACKUP_SUFFIX}"

    cp "$PROMETHEUS_CONFIG" "$backup_file"
    perl -0pi -e "s/targets: \['<PROD_SERVER_IP>:9100'\]/targets: ['${target_ip}:9100']/g" "$PROMETHEUS_CONFIG"

    if grep -q '<PROD_SERVER_IP>' "$PROMETHEUS_CONFIG"; then
        log_warn "Masih ada placeholder <PROD_SERVER_IP> di prometheus.yml. Cek file hasil edit."
    fi

    log_success "Prometheus target diperbarui ke ${target_ip}:9100"
    log_info "Backup konfigurasi disimpan di ${backup_file}"
}

setup_monitoring_server() {
    local target_ip="$1"
    local compose_cmd="$2"

    require_file "$PROMETHEUS_CONFIG"
    require_file "$COMPOSE_MONITORING"

    if ! validate_ip "$target_ip"; then
        log_error "Target server IP tidak valid: $target_ip"
        exit 1
    fi

    update_prometheus_target "$target_ip"

    log_info "Menjalankan monitoring stack..."
    $compose_cmd -f "$COMPOSE_MONITORING" up -d

    log_info "Menjalankan testing setelah startup..."
    run_monitoring_tests "$target_ip"

    log_success "Monitoring stack aktif"
    echo ""
    echo "Akses:"
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana:    http://localhost:3000"
    echo ""
    echo "Target yang discrape: ${target_ip}:9100"
}

setup_target_server() {
    local monitoring_ip="$1"
    local compose_cmd="$2"

    require_file "$COMPOSE_NODE_EXPORTER"

    if ! validate_ip "$monitoring_ip"; then
        log_error "Monitoring server IP tidak valid: $monitoring_ip"
        exit 1
    fi

    if command -v ufw >/dev/null 2>&1; then
        if sudo ufw status >/dev/null 2>&1; then
            log_info "Membuka port 9100 hanya untuk ${monitoring_ip} via ufw..."
            sudo ufw allow from "$monitoring_ip" to any port 9100 proto tcp || true
        else
            log_warn "ufw terpasang tetapi tidak aktif, lewati konfigurasi firewall"
        fi
    else
        log_warn "ufw tidak ditemukan, lewati konfigurasi firewall"
    fi

    log_info "Menjalankan node exporter di target server..."
    $compose_cmd -f "$COMPOSE_NODE_EXPORTER" up -d

    log_info "Menjalankan testing setelah startup..."
    run_target_server_tests

    log_success "Node exporter aktif"
    echo ""
    echo "Metrics endpoint: http://localhost:9100/metrics"
    echo "Monitoring server yang diizinkan: ${monitoring_ip}"
}

run_monitoring_tests() {
    local target_ip="$1"
    local failures=0

    if curl -fsS http://localhost:9090/-/healthy >/dev/null; then
        log_success "Test Prometheus health: OK"
    else
        log_error "Test Prometheus health: FAILED"
        failures=$((failures + 1))
    fi

    if curl -fsS http://localhost:3000/api/health >/dev/null; then
        log_success "Test Grafana health: OK"
    else
        log_error "Test Grafana health: FAILED"
        failures=$((failures + 1))
    fi

    if curl -fsS http://localhost:9090/api/v1/targets | grep -q "${target_ip}:9100"; then
        log_success "Test scrape target ${target_ip}:9100: OK"
    else
        log_error "Test scrape target ${target_ip}:9100: FAILED"
        failures=$((failures + 1))
    fi

    if [[ "$failures" -gt 0 ]]; then
        log_error "Monitoring setup test gagal (${failures} pemeriksaan gagal)"
        exit 1
    fi
}

run_target_server_tests() {
    local failures=0

    if curl -fsS http://localhost:9100/metrics >/dev/null; then
        log_success "Test node exporter metrics endpoint: OK"
    else
        log_error "Test node exporter metrics endpoint: FAILED"
        failures=$((failures + 1))
    fi

    if [[ "$failures" -gt 0 ]]; then
        log_error "Target server setup test gagal (${failures} pemeriksaan gagal)"
        exit 1
    fi
}

main() {
    if [[ $# -lt 1 ]]; then
        show_help
        exit 1
    fi

    local role="$1"
    local ip="${2:-}"
    local compose_cmd

    if [[ "$role" == "-h" || "$role" == "--help" || "$role" == "help" ]]; then
        show_help
        exit 0
    fi

    if [[ -z "$ip" ]]; then
        show_help
        exit 1
    fi

    if ! compose_cmd="$(detect_compose_cmd)"; then
        log_error "Docker Compose tidak ditemukan. Install Docker Compose terlebih dahulu."
        exit 1
    fi

    case "$role" in
        monitoring)
            setup_monitoring_server "$ip" "$compose_cmd"
            ;;
        target-server|target|production)
            setup_target_server "$ip" "$compose_cmd"
            ;;
        *)
            log_error "Role tidak dikenal: $role"
            show_help
            exit 1
            ;;
    esac
}

main "$@"