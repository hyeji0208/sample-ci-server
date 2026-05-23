#!/usr/bin/env bash
# EC2에서 Hub 이미지를 pull 후 컨테이너로 재기동 (GitHub Actions CD에서 호출)
set -euo pipefail

: "${DOCKER_IMAGE:?DOCKER_IMAGE is required}"
: "${DOCKERHUB_USERNAME:?DOCKERHUB_USERNAME is required}"
: "${DOCKERHUB_TOKEN:?DOCKERHUB_TOKEN is required}"

CONTAINER_NAME="${CONTAINER_NAME:-sample-ci-server}"
APP_PORT="${APP_PORT:-3000}"

if docker info &>/dev/null; then
  DOCKER=(docker)
elif sudo docker info &>/dev/null; then
  DOCKER=(sudo docker)
else
  echo "ERROR: Docker is not available. Run scripts/ec2-docker-bootstrap.sh on EC2 first."
  exit 1
fi

echo "==> Logging in to Docker Hub"
echo "$DOCKERHUB_TOKEN" | "${DOCKER[@]}" login -u "$DOCKERHUB_USERNAME" --password-stdin

echo "==> Pulling ${DOCKER_IMAGE}"
"${DOCKER[@]}" pull "$DOCKER_IMAGE"

echo "==> Replacing container ${CONTAINER_NAME}"
"${DOCKER[@]}" stop "$CONTAINER_NAME" 2>/dev/null || true
"${DOCKER[@]}" rm "$CONTAINER_NAME" 2>/dev/null || true

"${DOCKER[@]}" run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "${APP_PORT}:${APP_PORT}" \
  -e NODE_ENV=production \
  -e PORT="${APP_PORT}" \
  "$DOCKER_IMAGE"

echo "==> Waiting for app on port ${APP_PORT}"
for _ in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:${APP_PORT}/" >/dev/null; then
    echo "==> Deploy OK (${DOCKER_IMAGE})"
    "${DOCKER[@]}" ps --filter "name=${CONTAINER_NAME}"
    exit 0
  fi
  sleep 2
done

echo "ERROR: Health check failed. Container logs:"
"${DOCKER[@]}" logs --tail 50 "$CONTAINER_NAME" 2>/dev/null || true
exit 1
