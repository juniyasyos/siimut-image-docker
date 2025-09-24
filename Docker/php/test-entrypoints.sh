#!/usr/bin/env bash
set -euo pipefail

# test-entrypoints.sh — Testing script untuk semua entrypoints

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[test]${NC} $*"; }
success() { echo -e "${GREEN}[success]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test function
test_entrypoint() {
  local name="$1"
  local file="$2"
  local test_cmd="${3:-echo 'test command'}"
  
  log "Testing $name entrypoint..."
  
  if [[ ! -f "$file" ]]; then
    error "$name: File tidak ditemukan - $file"
    return 1
  fi
  
  if [[ ! -x "$file" ]]; then
    error "$name: File tidak executable - $file"
    return 1
  fi
  
  # Basic syntax check
  if ! bash -n "$file"; then
    error "$name: Syntax error detected"
    return 1
  fi
  
  success "$name: File OK"
  return 0
}

# Test all entrypoints
log "🧪 Testing SIIMUT Entrypoints"

declare -A entrypoints=(
  ["Enhanced"]="$SCRIPT_DIR/entrypoint-enhanced.sh"
  ["Production"]="$SCRIPT_DIR/entrypoint-production.sh" 
  ["Development"]="$SCRIPT_DIR/entrypoint-development.sh"
  ["Caddy"]="$SCRIPT_DIR/entrypoint-caddy.sh"
  ["Minimal"]="$SCRIPT_DIR/entrypoint-minimal.sh"
  ["Selector"]="$SCRIPT_DIR/entrypoint-selector.sh"
)

failed_tests=()

for name in "${!entrypoints[@]}"; do
  if ! test_entrypoint "$name" "${entrypoints[$name]}"; then
    failed_tests+=("$name")
  fi
done

echo
log "📊 Test Results:"

if [[ ${#failed_tests[@]} -eq 0 ]]; then
  success "✅ All entrypoints passed basic tests!"
else
  error "❌ Failed tests: ${failed_tests[*]}"
  exit 1
fi

# Test selector with different modes
log "🔧 Testing entrypoint selector modes..."

selector_file="$SCRIPT_DIR/entrypoint-selector.sh"

test_modes=("enhanced" "production" "development" "caddy" "minimal" "auto")

for mode in "${test_modes[@]}"; do
  log "Testing selector mode: $mode"
  
  # Test help and validation (dry run)
  if SIIMUT_DEBUG=true "$selector_file" "$mode" --help >/dev/null 2>&1 || 
     [[ "$mode" == "auto" ]] && SIIMUT_DEBUG=true "$selector_file" --help >/dev/null 2>&1; then
    success "Selector mode '$mode': OK"
  else
    warn "Selector mode '$mode': May have issues"
  fi
done

success "🎉 All tests completed!"

log "📝 Quick usage examples:"
echo "  # Production: ./entrypoint-selector.sh production php-fpm"
echo "  # Development: ./entrypoint-selector.sh development php-fpm"
echo "  # Auto-detect: ./entrypoint-selector.sh auto php-fpm"