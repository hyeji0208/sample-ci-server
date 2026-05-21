#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-$HOME/sample-server}"
cd "$APP_DIR"

echo "==> Deploy directory: $(pwd)"

if [[ ! -f dist/main.js ]]; then
  echo "ERROR: dist/main.js not found. Run CI build and scp dist/ first."
  exit 1
fi

export NODE_ENV=production

echo "==> Installing production dependencies"
npm install --omit=dev

echo "==> Stopping previous process"
pkill -f "dist/main.js" 2>/dev/null || true
sleep 1

echo "==> Starting application"
nohup node dist/main.js >> app.log 2>&1 &
sleep 2

if pgrep -f "dist/main.js" > /dev/null; then
  echo "==> Deploy OK (port ${PORT:-3000})"
  exit 0
fi

echo "ERROR: Application did not start. Recent logs:"
tail -30 app.log 2>/dev/null || true
exit 1
