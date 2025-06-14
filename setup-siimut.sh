#!/bin/bash

set -e

PROJECT_NAME="siimut"
LARAVEL_DIR="$HOME/Repos/project-laravel"
LARAVEL_PACKAGE="juniyasyos/siimut"

echo "🚀 Siimut Installer - Laravel & Docker Setup"
echo "============================================"
echo ""

# 1. Update dan install dependencies dasar
echo "🔧 [1/7] Update & install base dependencies..."
sudo apt update -y && sudo apt upgrade -y
for pkg in ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common; do
    dpkg -s $pkg &> /dev/null || sudo apt install -y $pkg
done

# 2. Tambah GPG key Docker
echo "🔑 [2/7] Setup Docker GPG key..."
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

# 3. Tambah Docker repo
echo "📦 [3/7] Tambah Docker repo ke apt source..."
DOCKER_LIST="/etc/apt/sources.list.d/docker.list"
if [ ! -f "$DOCKER_LIST" ]; then
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
      sudo tee "$DOCKER_LIST" > /dev/null
fi

# 4. Install Docker & Compose
echo "🐳 [4/7] Install Docker & Docker Compose..."
for pkg in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
    dpkg -s $pkg &> /dev/null || sudo apt install -y $pkg
done

# 5. Tambah user ke grup docker
echo "👤 [5/7] Menambahkan user '$USER' ke grup docker..."
if groups $USER | grep -qv '\bdocker\b'; then
    sudo usermod -aG docker $USER
    echo "🔄 Silakan jalankan 'newgrp docker' atau restart shell untuk aktifkan grup docker."
fi

# 6. Konfigurasi systemd untuk WSL2
echo "🧩 [6/7] Konfigurasi systemd untuk WSL (jika perlu)..."
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    sudo tee /etc/wsl.conf > /dev/null <<EOF
[boot]
systemd=true
EOF
    echo "✅ WSL systemd enabled. Jalankan: wsl --shutdown"
else
    echo "ℹ️  Non-WSL system detected, lewati konfigurasi systemd."
fi

# 7. Buat Laravel project jika belum ada
echo "📁 [7/7] Menyiapkan Laravel project di $LARAVEL_DIR..."
if [ ! -d "$LARAVEL_DIR" ]; then
    mkdir -p "$HOME/Repos"
    echo "📦 Meng-clone Laravel project $LARAVEL_PACKAGE ..."
    docker run --rm -v "$HOME/Repos:/app" -w /app composer create-project $LARAVEL_PACKAGE project-laravel
else
    echo "✅ Project Laravel sudah ada di: $LARAVEL_DIR"
fi

echo ""
echo "🎉 Setup selesai. Selanjutnya jalankan: docker compose up -d"
