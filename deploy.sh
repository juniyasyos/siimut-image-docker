#!/bin/bash

# Deploy SIIMUT with Ansible
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="production"
BRANCH="master"
INVENTORY="ansible/inventory.ini"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -i|--inventory)
            INVENTORY="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -e, --environment    Target environment (default: production)"
            echo "  -b, --branch         Git branch to deploy (default: master)"
            echo "  -i, --inventory      Ansible inventory file (default: ansible/inventory.ini)"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}🚀 Starting SIIMUT deployment...${NC}"
echo -e "${YELLOW}Environment: ${ENVIRONMENT}${NC}"
echo -e "${YELLOW}Branch: ${BRANCH}${NC}"
echo -e "${YELLOW}Inventory: ${INVENTORY}${NC}"

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}❌ Ansible is not installed. Please install Ansible first.${NC}"
    exit 1
fi

# Check if inventory file exists
if [ ! -f "$INVENTORY" ]; then
    echo -e "${RED}❌ Inventory file not found: $INVENTORY${NC}"
    exit 1
fi

# Run Ansible playbook
echo -e "${GREEN}📋 Running Ansible playbook...${NC}"
ansible-playbook \
    -i "$INVENTORY" \
    ansible/playbook.yml \
    -e "siimut_branch=$BRANCH" \
    -e "target_env=$ENVIRONMENT" \
    --diff

echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${YELLOW}🌐 Your application should be available at:${NC}"
echo -e "${YELLOW}   Application: http://your-server-ip:8000${NC}"
echo -e "${YELLOW}   phpMyAdmin: http://your-server-ip:8080${NC}"