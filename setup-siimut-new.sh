#!/usr/bin/env bash

# Multi-App Docker Setup Script with Git Clone
set -e

# =========================
# 🎨 Colors
# =========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

COMPOSE_FILE="docker-compose-multi-apps.yml"

echo -e "${GREEN}🚀 Multi App Docker Setup${NC}"
echo -e "${GREEN}==========================${NC}"

# =========================
# 🔧 Konfigurasi banyak repo
# Format: "APP_NAME|REPO_URL|BRANCH"
# =========================
APPS=(
#   "iam|https://github.com/juniyasyos/laravel-iam.git|dev"
  "siimut|https://github.com/juniyasyos/si-imut.git|feat-daily-report"
)

# Bisa di-override via ENV global kalau mau
DEFAULT_BRANCH="${SIIMUT_BRANCH:-fix-chart}"

# =========================
# 🧠 Fungsi bantu
# =========================
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

clone_or_update_repo() {
    local app_name="$1"
    local repo_url="$2"
    local branch="$3"

    # kalau branch kosong, pakai default
    if [[ -z "$branch" ]]; then
        branch="$DEFAULT_BRANCH"
    fi

    local dest_dir="site/${app_name}"

    echo -e "${BLUE}📦 Setting up app: ${YELLOW}${app_name}${NC}"
    echo -e "   📂 Repo   : ${repo_url}"
    echo -e "   🌿 Branch : ${branch}"

    if [ ! -d "${dest_dir}" ]; then
        echo -e "${YELLOW}📥 Cloning repository ke ${dest_dir}...${NC}"
        git clone --depth 1 -b "${branch}" "${repo_url}" "${dest_dir}"
        echo -e "${GREEN}✅ ${app_name} cloned successfully${NC}"
    elif [ -d "${dest_dir}/.git" ]; then
        echo -e "${YELLOW}🔄 Updating existing repository di ${dest_dir}...${NC}"
        pushd "${dest_dir}" >/dev/null
        git fetch origin "${branch}"
        git checkout "${branch}"
        git pull origin "${branch}"
        popd >/dev/null
        echo -e "${GREEN}✅ ${app_name} updated successfully${NC}"
    else
        echo -e "${RED}❌ ${dest_dir} exists but is not a git repository${NC}"
        echo -e "${YELLOW}   Hapus folder ${dest_dir} lalu jalankan script lagi${NC}"
        exit 1
    fi

    echo ""
}

copy_env_if_needed() {
    local app_name="$1"
    local app_dir="site/${app_name}"

    echo -e "${BLUE}🔐 ENV setup for ${YELLOW}${app_name}${NC}"

    if [ -f "${app_dir}/.env" ]; then
        echo -e "${YELLOW}   ⚠️ .env already exists — skipping copy${NC}"
        return
    fi

    if [ -f "${app_dir}/.env.example" ]; then
        cp "${app_dir}/.env.example" "${app_dir}/.env"
        echo -e "${GREEN}   ✅ .env copied from .env.example${NC}"
    elif [ -f "${app_dir}/.env.example.local" ]; then
        cp "${app_dir}/.env.example.local" "${app_dir}/.env"
        echo -e "${GREEN}   ✅ .env copied from .env.example.local${NC}"
    else
        echo -e "${YELLOW}   ⚠️ No .env.example found — skipping${NC}"
    fi

    echo ""
}


# 🔧 NEW: Install composer/npm + build per app
install_app_dependencies() {
    local app_name="$1"
    local app_dir="site/${app_name}"

    echo -e "${BLUE}🔧 Installing dependencies for ${YELLOW}${app_name}${NC}"

    # Composer install (kalau ada composer.json dan composer terpasang)
    if command_exists composer && [ -f "${app_dir}/composer.json" ]; then
        echo -e "${YELLOW}   ▶ Running composer install...${NC}"
        pushd "${app_dir}" >/dev/null
        composer install --no-interaction --prefer-dist --optimize-autoloader \
            || echo -e "${RED}   ❌ composer install failed in ${app_name}${NC}"
        popd >/dev/null
    else
        echo -e "${YELLOW}   ⚠️ Skip composer (tidak ada composer.json atau composer belum terinstall)${NC}"
    fi

    # NPM install + build (kalau ada package.json dan npm terpasang)
    if command_exists npm && [ -f "${app_dir}/package.json" ]; then
        pushd "${app_dir}" >/dev/null
        echo -e "${YELLOW}   ▶ Running npm install...${NC}"
        npm install || echo -e "${RED}   ❌ npm install failed in ${app_name}${NC}"

        # Cek ada script "build" di package.json (cek sederhana)
        if grep -q "\"build\"" package.json; then
            echo -e "${YELLOW}   ▶ Running npm run build...${NC}"
            npm run build || echo -e "${RED}   ❌ npm run build failed in ${app_name}${NC}"
        else
            echo -e "${YELLOW}   ⚠️ Tidak ditemukan script build, skip npm run build${NC}"
        fi

        popd >/dev/null
    else
        echo -e "${YELLOW}   ⚠️ Skip npm (tidak ada package.json atau npm belum terinstall)${NC}"
    fi

    echo ""
}

# =========================
# 📋 Cek dependency
# =========================
echo -e "${BLUE}📋 Checking dependencies...${NC}"

if ! command_exists git; then
    echo -e "${RED}❌ Git is not installed. Please install Git first.${NC}"
    exit 1
fi

if ! command_exists docker; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! command_exists docker compose; then
    echo -e "${RED}❌ Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All dependencies are installed${NC}"
echo ""

# =========================
# 📁 Struktur direktori
# =========================
echo -e "${BLUE}📁 Creating required directories...${NC}"
mkdir -p site
mkdir -p Docker/{caddy/{data,config},db/{data,sql},redis/data,phpmyadmin/sessions,logs}

# Set proper permissions
chmod 755 Docker/phpmyadmin/sessions
chown -R 33:33 Docker/phpmyadmin/sessions 2>/dev/null || true

# =========================
# 📥 Clone / update semua repo
# =========================
echo -e "${BLUE}📦 Processing application repositories...${NC}"

for app_def in "${APPS[@]}"; do
    IFS='|' read -r APP_NAME REPO_URL BRANCH <<< "${app_def}"
    clone_or_update_repo "${APP_NAME}" "${REPO_URL}" "${BRANCH}"
done

for app_def in "${APPS[@]}"; do
    IFS='|' read -r APP_NAME REPO_URL BRANCH <<< "${app_def}"
    clone_or_update_repo "${APP_NAME}" "${REPO_URL}" "${BRANCH}"
    copy_env_if_needed "${APP_NAME}"          # ⬅️ tambahan baru
done

# =========================
# 🔧 NEW: Jalankan composer/npm/build untuk semua app
# =========================
echo -e "${BLUE}🔧 Installing PHP & JS dependencies for all apps...${NC}"
for app_def in "${APPS[@]}"; do
    IFS='|' read -r APP_NAME REPO_URL BRANCH <<< "${app_def}"
    install_app_dependencies "${APP_NAME}"
done

# =========================
# 🔐 Caddyfile check
# =========================
if [ ! -f "DockerNew/caddy/Caddyfile" ]; then
    echo -e "${RED}❌ Caddyfile not found. Please create DockerNew/caddy/Caddyfile${NC}"
    echo -e "${YELLOW}   Contoh: map domain/subdomain ke masing-masing app container.${NC}"
    exit 1
fi

# =========================
# ✅ Summary
# =========================
echo ""
echo -e "${GREEN}🎉 Multi-app setup completed successfully!${NC}"
echo ""
echo -e "${BLUE}📂 Project Structure:${NC}"
echo -e "${YELLOW}• Docker configs   :${NC} ./Docker/"
echo -e "${YELLOW}• Applications code:${NC} ./site/<app_name>/"
echo -e "${YELLOW}• Environment      :${NC} ./.env"
echo ""
echo -e "${BLUE}📦 Apps configured:${NC}"
for app_def in "${APPS[@]}"; do
    IFS='|' read -r APP_NAME REPO_URL BRANCH <<< "${app_def}"
    echo -e "  - ${YELLOW}${APP_NAME}${NC} → ./site/${APP_NAME}  (${BRANCH})"
done
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo -e "${YELLOW}1.${NC} Start services:  docker-compose -f ${COMPOSE_FILE} up -d"
echo -e "${YELLOW}2.${NC} Check status :   docker-compose -f ${COMPOSE_FILE} ps"
echo -e "${YELLOW}3.${NC} View logs   :   docker-compose -f ${COMPOSE_FILE} logs -f"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
