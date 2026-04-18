#!/bin/bash

####################################################################################################
# SIIMUT Build & Push to Docker Hub Script
# 
# Purpose: Build SIIMUT image, tag it, and push to Docker Hub
# Usage:
#   ./build.sh              # Build only, tag as latest
#   ./build.sh push         # Build and push to Docker Hub
#   ./build.sh tag          # Build and tag (no push)
#   VERSION=v1.0.0 ./build.sh push  # Build specific version
#
# Configuration:
#   - DOCKER_HUB_USER: Set in environment or defaults to 'juni'
#   - VERSION: Read from ./VERSION file or environment variable
#   - IMAGE_NAME: 'siimut' (hardcoded)
####################################################################################################

set -e

# ============================================
# Configuration
# ============================================
DOCKER_HUB_USER="${DOCKER_HUB_USER:-juni}"
IMAGE_NAME="siimut"
COMPOSE_FILE="docker-compose-build.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read version: ENV VAR > VERSION file > 'latest'
if [ -z "$VERSION" ]; then
    if [ -f "$SCRIPT_DIR/VERSION" ]; then
        VERSION=$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')
    else
        VERSION="latest"
    fi
fi

# Full image references
LOCAL_IMAGE="$IMAGE_NAME:latest"
DOCKER_HUB_IMAGE_VERSIONED="$DOCKER_HUB_USER/$IMAGE_NAME:$VERSION"
DOCKER_HUB_IMAGE_LATEST="$DOCKER_HUB_USER/$IMAGE_NAME:latest"

# Command: build, tag, push, or all
COMMAND="${1:-build}"

# ============================================
# Colors for output
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Functions
# ============================================

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

print_config() {
    echo ""
    echo "╔════════════════════════════════════════════╗"
    echo "║  SIIMUT Build Configuration               ║"
    echo "╠════════════════════════════════════════════╣"
    echo "║  Docker Hub User:  $DOCKER_HUB_USER"
    echo "║  Image Name:       $IMAGE_NAME"
    echo "║  Version:          $VERSION"
    echo "║  Local Image:      $LOCAL_IMAGE"
    echo "║  Docker Hub Image: $DOCKER_HUB_IMAGE_VERSIONED"
    echo "║  Latest Tag:       $DOCKER_HUB_IMAGE_LATEST"
    echo "║  Compose File:     $COMPOSE_FILE"
    echo "║  Command:          $COMMAND"
    echo "╚════════════════════════════════════════════╝"
    echo ""
}

build_image() {
    log_info "Building $LOCAL_IMAGE from $COMPOSE_FILE..."
    
    if docker compose -f "$SCRIPT_DIR/$COMPOSE_FILE" build; then
        log_success "Build completed successfully"
        return 0
    else
        log_error "Build failed"
        return 1
    fi
}

tag_image() {
    log_info "Tagging image..."
    
    if docker tag "$LOCAL_IMAGE" "$DOCKER_HUB_IMAGE_VERSIONED"; then
        log_success "Tagged: $LOCAL_IMAGE → $DOCKER_HUB_IMAGE_VERSIONED"
    else
        log_error "Failed to tag image with version"
        return 1
    fi
    
    if docker tag "$LOCAL_IMAGE" "$DOCKER_HUB_IMAGE_LATEST"; then
        log_success "Tagged: $LOCAL_IMAGE → $DOCKER_HUB_IMAGE_LATEST"
    else
        log_error "Failed to tag image as latest"
        return 1
    fi
    
    return 0
}

verify_docker_login() {
    log_info "Verifying Docker Hub authentication..."
    
    if ! docker info | grep -q "Username:"; then
        log_warn "Not logged in to Docker Hub"
        log_info "Please login first:"
        log_info "  docker login"
        return 1
    fi
    
    log_success "Docker Hub authentication verified"
    return 0
}

push_image() {
    log_info "Pushing images to Docker Hub..."
    
    if ! verify_docker_login; then
        log_error "Cannot push without Docker Hub login"
        return 1
    fi
    
    # Push versioned tag
    if docker push "$DOCKER_HUB_IMAGE_VERSIONED"; then
        log_success "Pushed: $DOCKER_HUB_IMAGE_VERSIONED"
    else
        log_error "Failed to push $DOCKER_HUB_IMAGE_VERSIONED"
        return 1
    fi
    
    # Push latest tag
    if docker push "$DOCKER_HUB_IMAGE_LATEST"; then
        log_success "Pushed: $DOCKER_HUB_IMAGE_LATEST"
    else
        log_error "Failed to push $DOCKER_HUB_IMAGE_LATEST"
        return 1
    fi
    
    return 0
}

show_help() {
    cat << EOF
╔════════════════════════════════════════════════════════════════╗
║            SIIMUT Build & Docker Hub Push Tool                ║
╚════════════════════════════════════════════════════════════════╝

USAGE:
    ./build.sh [COMMAND]

COMMANDS:
    build                  Build image only (default)
    tag                    Build and tag for Docker Hub
    push                   Build, tag, and push to Docker Hub
    help                   Show this help message

EXAMPLES:
    # Build image locally
    ./build.sh

    # Build and tag
    ./build.sh tag

    # Build, tag, and push to Docker Hub
    ./build.sh push

    # Build specific version
    VERSION=v1.0.1 ./build.sh push

ENVIRONMENT VARIABLES:
    DOCKER_HUB_USER        Docker Hub username (default: juni)
    VERSION                Image version (default: read from VERSION file)

CONFIGURATION FILES:
    VERSION                Contains version string (e.g., v1.0.0)
    docker-compose-build.yml  Build manifest

NOTES:
    - VERSION file should contain only version string (e.g., v1.0.0)
    - Requires Docker daemon running
    - For push: requires 'docker login' to be successful
    - Images are tagged as:
        * Local: siimut:latest
        * Docker Hub: juni/siimut:VERSION
        * Docker Hub: juni/siimut:latest

╔════════════════════════════════════════════════════════════════╗
EOF
}

# ============================================
# Main Execution
# ============================================

print_config

case "$COMMAND" in
    build)
        log_info "Mode: BUILD ONLY"
        build_image
        ;;
    tag)
        log_info "Mode: BUILD & TAG"
        build_image && tag_image
        ;;
    push)
        log_info "Mode: BUILD, TAG & PUSH"
        build_image && tag_image && push_image
        ;;
    help|--help|-h)
        show_help
        exit 0
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo ""
    log_success "Build process completed successfully!"
    echo ""
    echo "Next steps:"
    case "$COMMAND" in
        build)
            echo "  • Tag image:     ./build.sh tag"
            echo "  • Push to Docker Hub: ./build.sh push"
            ;;
        tag)
            echo "  • Push to Docker Hub: ./build.sh push"
            ;;
        push)
            echo "  • Deploy: VERSION=$VERSION docker-compose -f docker-compose-multi-apps.yml pull"
            echo "  • Run:    VERSION=$VERSION docker-compose -f docker-compose-multi-apps.yml up -d"
            ;;
    esac
    echo ""
else
    echo ""
    log_error "Build process failed!"
    exit 1
fi
