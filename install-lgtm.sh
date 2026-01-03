#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/otel-lgtm"
REPO_URL="https://github.com/grafana/docker-otel-lgtm.git"
DATA_ROOT="/data/otel-lgtm"
SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"

echo "===> Updating system"
sudo apt update -y
sudo apt upgrade -y

echo "===> Installing base packages"
sudo apt install -y ca-certificates curl git

echo "===> Installing Docker (if not installed)"
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
fi

echo "===> Installing Docker Compose v2"
sudo apt install -y docker-compose-plugin

echo "===> Adding current user to docker group"
sudo usermod -aG docker "$USER" || true

echo "===> Ensuring application directory exists"
sudo mkdir -p "$APP_DIR"
sudo chown -R "$USER:$USER" "$APP_DIR"

echo "===> Syncing upstream repo (idempotent; optional, mantém referência)"
if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" pull --ff-only || true
elif [ -z "$(ls -A "$APP_DIR")" ]; then
  git clone "$REPO_URL" "$APP_DIR"
else
  echo "Directory not empty and not a git repo; skipping clone"
fi

echo "===> Preparing persistent data dir at ${DATA_ROOT}"
sudo mkdir -p "$DATA_ROOT"
# UID 472 é usado pelo usuário 'grafana' (ajuste se necessário no seu host)
sudo chown -R 472:472 "$DATA_ROOT" || true

echo "===> Installing compose.yaml into ${APP_DIR}"
cp "${SCRIPT_DIR}/compose.yaml" "${APP_DIR}/compose.yaml"
sudo chown "$USER:$USER" "${APP_DIR}/compose.yaml"

echo "===> Pulling images"
docker compose -f "${APP_DIR}/compose.yaml" pull

echo "===> Starting stack (up -d)"
docker compose -f "${APP_DIR}/compose.yaml" up -d

echo "===> Done. Logs: docker compose -f ${APP_DIR}/compose.yaml logs -f"