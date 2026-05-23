#!/usr/bin/env bash
# Amazon Linux 2023 (ec2-user) — Docker CD 최초 1회 (SSH 접속 후 실행)
set -euo pipefail

echo "==> Installing Docker"
sudo yum update -y
sudo yum install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

echo "==> Bootstrap complete."
echo "    1) SSH 세션을 다시 연결하세요 (docker 그룹 적용)."
echo "    2) docker run hello-world 로 동작 확인."
echo "    3) GitHub Secrets 설정 후 main/master push → CD 자동 배포."
