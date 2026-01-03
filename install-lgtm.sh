#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/otel-lgtm"
REPO_URL="https://github.com/grafana/docker-otel-lgtm.git"
DATA_ROOT="/data/otel-lgtm"
SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"

# Check Ubuntu 22.04
echo "===> Checking OS compatibility"
if [ -f /etc/os-release ]; then
  . /etc/os-release
  if [ "$ID" != "ubuntu" ] || [[ "$VERSION_ID" != "22.04"* ]]; then
    echo "ERROR: This script only supports Ubuntu 22.04 LTS"
    echo "Detected: $ID $VERSION_ID"
    exit 1
  fi
  echo "OK: Ubuntu $VERSION_ID detected"
else
  echo "ERROR: Cannot detect OS. This script only supports Ubuntu 22.04 LTS"
  exit 1
fi

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

echo "===> Cleaning up installation files"
rm -f "${SCRIPT_DIR}/compose.yaml" 2>/dev/null || true
rm -f "${SCRIPT_DIR}/readme.md" 2>/dev/null || true
rm -f "${SCRIPT_DIR}/README.md" 2>/dev/null || true
rm -f "${SCRIPT_DIR}/install-lgtm.sh" 2>/dev/null || true

echo ""
echo "===> Contents of ${APP_DIR}:"
ls -la "${APP_DIR}"

echo ""
echo "===> Stack status:"
docker compose -f "${APP_DIR}/compose.yaml" ps

echo ""
echo "============================================"
echo "===> Installation complete!"
echo "============================================"
echo ""
echo "To go to the application directory, run:"
echo "  cd ${APP_DIR}"
echo ""
echo "Useful commands:"
echo "  Logs:    docker compose -f ${APP_DIR}/compose.yaml logs -f"
echo "  Stop:    docker compose -f ${APP_DIR}/compose.yaml down"
echo "  Restart: docker compose -f ${APP_DIR}/compose.yaml restart"
echo ""

# Remove the installation directory (must be last)
cd /
rm -rf "${SCRIPT_DIR}" 2>/dev/null || true