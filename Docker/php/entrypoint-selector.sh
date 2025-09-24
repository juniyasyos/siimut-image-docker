#!/usr/bin/env bash
set -euo pipefail

# entrypoint-selector.sh — Utilitas untuk memilih entrypoint yang tepat
# 
# Usage:
#   ./entrypoint-selector.sh [mode] [args...]
#
# Modes:
#   enhanced    - Full-featured entrypoint (default)
#   production  - Lightweight production
#   development - Development with debugging
#   caddy       - Optimized for Caddy server
#   minimal     - Ultra-minimal bootstrap
#   auto        - Auto-detect based on environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[selector]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*" >&2; }
success() { echo -e "${GREEN}[success]${NC} $*"; }

# Show help
show_help() {
  cat << EOF
SIIMUT Entrypoint Selector

Usage: $0 [MODE] [COMMAND...]

Available modes:
  enhanced    - Full-featured entrypoint with all features
                (database waiting, optimization, health checks)
                
  production  - Lightweight production entrypoint
                (fast startup, minimal resources, security focus)
                
  development - Development-focused entrypoint  
                (hot reload, debugging, auto-migrations)
                
  caddy       - Optimized for Caddy web server
                (static file optimization, health checks)
                
  minimal     - Ultra-minimal bootstrap
                (testing, debugging, fastest startup)
                
  auto        - Auto-detect based on environment variables
                (APP_ENV, SIIMUT_MODE, container labels)

Environment Variables:
  SIIMUT_MODE           - Override mode selection
  SIIMUT_ENTRYPOINT     - Direct entrypoint file path
  APP_ENV               - Application environment (local/staging/production)
  SIIMUT_DEBUG=true     - Enable debug output

Examples:
  $0 enhanced php-fpm
  $0 development php-fpm  
  $0 auto php-fpm
  SIIMUT_MODE=production $0 auto php-fpm

EOF
}

# Auto-detect mode based on environment
auto_detect_mode() {
  # Priority 1: Direct SIIMUT_MODE override
  if [[ -n "${SIIMUT_MODE:-}" ]]; then
    echo "$SIIMUT_MODE"
    return
  fi
  
  # Priority 2: Check for Caddy
  if [[ -n "${CADDY_ADMIN:-}" ]] || [[ -f "/etc/caddy/Caddyfile" ]] || pgrep -f caddy >/dev/null 2>&1; then
    echo "caddy"
    return
  fi
  
  # Priority 3: Check APP_ENV
  case "${APP_ENV:-production}" in
    "local"|"dev"|"development")
      echo "development"
      return
      ;;
    "testing"|"test")
      echo "minimal"
      return
      ;;
    "staging"|"prod"|"production")
      echo "production"
      return
      ;;
  esac
  
  # Priority 4: Check Docker/container environment
  if [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]]; then
    echo "production"  # K8s usually production
    return
  fi
  
  if [[ -f "/.dockerenv" ]]; then
    # Check docker-compose labels or environment
    if [[ "${COMPOSE_PROJECT_NAME:-}" == *"dev"* ]] || [[ "${COMPOSE_SERVICE:-}" == *"dev"* ]]; then
      echo "development"
      return
    fi
  fi
  
  # Default fallback
  echo "enhanced"
}

# Validate entrypoint file exists and is executable
validate_entrypoint() {
  local entrypoint_file="$1"
  
  if [[ ! -f "$entrypoint_file" ]]; then
    error "Entrypoint file not found: $entrypoint_file"
    return 1
  fi
  
  if [[ ! -x "$entrypoint_file" ]]; then
    warn "Making entrypoint executable: $entrypoint_file"
    chmod +x "$entrypoint_file" || {
      error "Failed to make entrypoint executable"
      return 1
    }
  fi
  
  return 0
}

# Get entrypoint file for mode
get_entrypoint_file() {
  local mode="$1"
  case "$mode" in
    "enhanced"|"full")
      echo "$SCRIPT_DIR/entrypoint-enhanced.sh"
      ;;
    "production"|"prod")
      echo "$SCRIPT_DIR/entrypoint-production.sh"
      ;;
    "development"|"dev"|"local")
      echo "$SCRIPT_DIR/entrypoint-development.sh"
      ;;
    "caddy")
      echo "$SCRIPT_DIR/entrypoint-caddy.sh"
      ;;
    "minimal"|"test"|"debug")
      echo "$SCRIPT_DIR/entrypoint-minimal.sh"
      ;;
    *)
      error "Unknown mode: $mode"
      echo ""
      ;;
  esac
}

# Main logic
main() {
  # Check if help requested
  if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
    exit 0
  fi
  
  local mode="$1"
  shift || true
  
  # Handle direct entrypoint override
  if [[ -n "${SIIMUT_ENTRYPOINT:-}" ]]; then
    log "Using direct entrypoint override: $SIIMUT_ENTRYPOINT"
    if validate_entrypoint "$SIIMUT_ENTRYPOINT"; then
      exec "$SIIMUT_ENTRYPOINT" "$@"
    else
      exit 1
    fi
  fi
  
  # Auto-detect if requested
  if [[ "$mode" == "auto" ]]; then
    mode=$(auto_detect_mode)
    log "Auto-detected mode: $mode"
  fi
  
  # Get entrypoint file
  local entrypoint_file
  entrypoint_file=$(get_entrypoint_file "$mode")
  
  if [[ -z "$entrypoint_file" ]]; then
    error "No entrypoint available for mode: $mode"
    echo
    show_help
    exit 1
  fi
  
  # Validate and execute
  if validate_entrypoint "$entrypoint_file"; then
    log "Using entrypoint: $(basename "$entrypoint_file") (mode: $mode)"
    
    # Debug info if requested
    if [[ "${SIIMUT_DEBUG:-false}" == "true" ]]; then
      log "Debug info:"
      log "  Mode: $mode"
      log "  Entrypoint: $entrypoint_file"  
      log "  APP_ENV: ${APP_ENV:-unset}"
      log "  SIIMUT_MODE: ${SIIMUT_MODE:-unset}"
      log "  Command: $*"
      log "  Working dir: $(pwd)"
    fi
    
    exec "$entrypoint_file" "$@"
  else
    exit 1
  fi
}

main "$@"