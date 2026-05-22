#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_BASE="$SCRIPT_DIR/docker-compose.base.yml"
COMPOSE_APPS="$SCRIPT_DIR/docker-compose-multi-apps.yml"
ENV_DEV="$SCRIPT_DIR/env/.env.dev"
ENV_PROD="$SCRIPT_DIR/env/.env.prod"

usage() {
  cat <<'EOF'
Usage:
  ./dc.sh up --dev
  ./dc.sh down --dev
  ./dc.sh rebuild --v --prod

Commands:
  up       Start stack in detached mode
  down     Stop stack
  rebuild  Pull images and recreate containers

Flags:
  --dev      Use env/.env.dev
  --prod     Use env/.env.prod
  --v        Verbose docker compose output
  -h, --help Show this help

Defaults:
  - Environment: dev
  - Compose files: docker-compose.base.yml + docker-compose-multi-apps.yml
EOF
}

log() {
  printf '%s\n' "$1"
}

error() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

ACTION="${1:-}"
shift || true

case "$ACTION" in
  up|down|rebuild)
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    error "Unknown command: $ACTION"
    ;;
esac

MODE="dev"
VERBOSE="false"
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dev)
      MODE="dev"
      ;;
    --prod)
      MODE="prod"
      ;;
    --v|--verbose|-v)
      VERBOSE="true"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      EXTRA_ARGS+=("$1")
      ;;
  esac
  shift
 done

if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  error "Unexpected argument(s): ${EXTRA_ARGS[*]}"
fi

ENV_FILE="$ENV_DEV"
if [[ "$MODE" == "prod" ]]; then
  ENV_FILE="$ENV_PROD"
fi

if [[ ! -f "$ENV_FILE" ]]; then
  error "Missing env file: $ENV_FILE"
fi

compose_cmd=(docker compose --env-file "$ENV_FILE" -f "$COMPOSE_BASE" -f "$COMPOSE_APPS")
if [[ "$VERBOSE" == "true" ]]; then
  compose_cmd=(docker compose --verbose --env-file "$ENV_FILE" -f "$COMPOSE_BASE" -f "$COMPOSE_APPS")
fi

case "$ACTION" in
  up)
    log "Starting stack using $(basename "$ENV_FILE")"
    "${compose_cmd[@]}" up -d
    ;;
  down)
    log "Stopping stack using $(basename "$ENV_FILE")"
    "${compose_cmd[@]}" down
    ;;
  rebuild)
    log "Rebuilding stack using $(basename "$ENV_FILE")"
    "${compose_cmd[@]}" pull
    "${compose_cmd[@]}" up -d --force-recreate --remove-orphans
    ;;
esac
