#!/bin/bash

# File: ansible-run.sh

set -e

echo "🌐 Memastikan sistem kamu siap..."

sudo apt update -y
sudo apt install -y python3 python3-pip sshpass software-properties-common pipx

echo "📦 Menginstall Ansible..."
pipx install ansible

echo "✅ Ansible berhasil diinstall!"

echo "🚀 Menjalankan playbook Ansible..."
ansible-playbook playbook.yml

echo "🎉 Semua proses selesai! Kamu siap pakai Docker & Compose!"
