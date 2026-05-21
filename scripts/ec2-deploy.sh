#!/usr/bin/env bash
# EC2에서 수동 배포 후 실행 (로컬 scp 이후)
set -euo pipefail

APP_DIR="${1:-$HOME/sample-server}"
cd "$APP_DIR"

export NODE_ENV=production
npm install --omit=dev
pkill -f "node dist/main" 2>/dev/null || true
nohup npm run start:prod >> app.log 2>&1 &
echo "==> Started at ${APP_DIR} (log: app.log)"
