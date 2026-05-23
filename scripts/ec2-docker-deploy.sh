#!/usr/bin/env bash
# EC2에서 Hub 이미지를 pull 후 컨테이너로 재기동 (GitHub Actions CD에서 호출)
set -euo pipefail

: "${DOCKER_IMAGE:?DOCKER_IMAGE is required}"
: "${DOCKERHUB_USERNAME:?DOCKERHUB_USERNAME is required}"
: "${DOCKERHUB_TOKEN:?DOCKERHUB_TOKEN is required}"

CONTAINER_NAME="${CONTAINER_NAME:-sample-server}"
APP_PORT="${APP_PORT:-3000}"

log() { echo "==> $*"; }

if docker info &>/dev/null; then
  DOCKER=(docker)
elif sudo docker info &>/dev/null; then
  DOCKER=(sudo docker)
else
  echo "ERROR: Docker is not available. Run scripts/ec2-docker-bootstrap.sh on EC2 first."
  exit 1
fi

free_port() {
  log "Freeing port ${APP_PORT}"
  "${DOCKER[@]}" stop "$CONTAINER_NAME" 2>/dev/null || true
  "${DOCKER[@]}" rm "$CONTAINER_NAME" 2>/dev/null || true

  while read -r cid; do
    [[ -z "$cid" ]] && continue
    log "Stopping container ${cid} using port ${APP_PORT}"
    "${DOCKER[@]}" stop "$cid" 2>/dev/null || true
    "${DOCKER[@]}" rm "$cid" 2>/dev/null || true
  done < <("${DOCKER[@]}" ps -q --filter "publish=${APP_PORT}" 2>/dev/null || true)

  if command -v ss >/dev/null && ss -tln 2>/dev/null | grep -q ":${APP_PORT} "; then
    log "Port ${APP_PORT} still bound (non-Docker process); trying fuser"
    sudo fuser -k "${APP_PORT}/tcp" 2>/dev/null || true
    sleep 2
  fi
}

log "Logging in to Docker Hub"
echo "$DOCKERHUB_TOKEN" | "${DOCKER[@]}" login -u "$DOCKERHUB_USERNAME" --password-stdin

log "Pulling ${DOCKER_IMAGE}"
"${DOCKER[@]}" pull "$DOCKER_IMAGE"

free_port

log "Starting container ${CONTAINER_NAME}"
"${DOCKER[@]}" run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "${APP_PORT}:${APP_PORT}" \
  -e NODE_ENV=production \
  -e PORT="${APP_PORT}" \
  "$DOCKER_IMAGE"

log "Waiting for app on port ${APP_PORT}"
for i in $(seq 1 30); do
  if command -v curl >/dev/null && curl -sf "http://127.0.0.1:${APP_PORT}/" >/dev/null; then
    log "Deploy OK (${DOCKER_IMAGE})"
    "${DOCKER[@]}" ps --filter "name=${CONTAINER_NAME}"
    exit 0
  fi
  if "${DOCKER[@]}" exec "$CONTAINER_NAME" node -e \
    "require('http').get('http://127.0.0.1:${APP_PORT}/',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))" \
    2>/dev/null; then
    log "Deploy OK via container health check (${DOCKER_IMAGE})"
    "${DOCKER[@]}" ps --filter "name=${CONTAINER_NAME}"
    exit 0
  fi
  if ! "${DOCKER[@]}" inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q true; then
    echo "ERROR: Container exited unexpectedly:"
    "${DOCKER[@]}" logs --tail 50 "$CONTAINER_NAME" 2>/dev/null || true
    exit 1
  fi
  echo "  ... attempt ${i}/30"
  sleep 2
done

echo "ERROR: Health check failed. Container logs:"
"${DOCKER[@]}" logs --tail 50 "$CONTAINER_NAME" 2>/dev/null || true
exit 1
