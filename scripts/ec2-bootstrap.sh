#!/usr/bin/env bash
# EC2 인스턴스 최초 1회 실행 (SSH 접속 후)
# Ubuntu 22.04/24.04 기준
set -euo pipefail

DEPLOY_PATH="${1:-/home/ubuntu/app}"

echo "==> Installing Node.js 22 (NodeSource)"
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

echo "==> Installing PM2"
sudo npm install -g pm2
pm2 startup systemd -u "$USER" --hp "$HOME" | tail -1 | bash || true

echo "==> Creating deploy directory: ${DEPLOY_PATH}"
mkdir -p "${DEPLOY_PATH}/scripts"

echo "==> Bootstrap complete."
echo "    Next: add GitHub Secrets and push to main/master."
