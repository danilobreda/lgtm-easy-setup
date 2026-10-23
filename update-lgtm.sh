#!/usr/bin/env bash
set -euo pipefail

# update-lgtm.sh
# (Re)generates all config files (compose.yaml, loki-config.yaml, tempo-config.yaml)
# and updates the LGTM stack to the latest image. Safe to re-run at any time.
# It also creates a swap file if the host has none, backs up Grafana's data before
# a version change, and waits until the stack is healthy (exit 1 + rollback steps if not).
#
# Usage:
#   ./update-lgtm.sh                 # normal update
#   ./update-lgtm.sh --purge-loki    # EMERGENCY: also deletes ALL stored logs
#                                    # (use when the disk is 100% full)
#
# Can also be run without cloning the repo (useful when the disk is full):
#   curl -fsSL https://raw.githubusercontent.com/danilobreda/lgtm-easy-setup/main/update-lgtm.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/danilobreda/lgtm-easy-setup/main/update-lgtm.sh | bash -s -- --purge-loki

APP_DIR="/opt/otel-lgtm"
DATA_ROOT="/data/otel-lgtm"
COMPOSE_FILE="${APP_DIR}/compose.yaml"
IMAGE="grafana/otel-lgtm:latest"

# --- Retention windows (edit here if you need different values) ---
LOKI_RETENTION="720h"       # logs: 30 days
TEMPO_RETENTION="360h"      # traces: 15 days
PROMETHEUS_RETENTION="30d"  # metrics: 30 days

# Swap file created at /swapfile when the host has no swap (0 = don't create).
# Without swap, a memory spike makes the kernel OOM-kill Prometheus, and the image
# never restarts a component that dies, so metrics stop silently.
SWAP_SIZE_GB=4

PURGE_LOKI=false
for arg in "$@"; do
  case "$arg" in
    --purge-loki) PURGE_LOKI=true ;;
    *) echo "Unknown option: $arg"; echo "Usage: $0 [--purge-loki]"; exit 1 ;;
  esac
done

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

echo "===> Ensuring ${APP_DIR} exists"
$SUDO mkdir -p "$APP_DIR"

echo "===> Generating ${COMPOSE_FILE}"
$SUDO tee "$COMPOSE_FILE" > /dev/null <<EOF
services:
  otel-lgtm:
    image: ${IMAGE}
    container_name: otel-lgtm
    restart: unless-stopped
    ports:
      - "3000:3000"  # Grafana UI
      - "4317:4317"  # OTLP gRPC
      - "4318:4318"  # OTLP HTTP
    volumes:
      - ${DATA_ROOT}:/data
      # Custom configs with data retention (upstream defaults have none for Loki)
      - ./loki-config.yaml:/otel-lgtm/loki-config.yaml:ro   # logs: ${LOKI_RETENTION}
      - ./tempo-config.yaml:/otel-lgtm/tempo-config.yaml:ro # traces: ${TEMPO_RETENTION}
    environment:
      - ENABLE_LOGS_ALL=true
      # Metrics retention (upstream default is 15d)
      - PROMETHEUS_EXTRA_ARGS=--storage.tsdb.retention.time=${PROMETHEUS_RETENTION}
    # Cap the container's own stdout log file (unbounded by default and
    # ENABLE_LOGS_ALL=true makes it grow fast)
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "3"
EOF

echo "===> Generating ${APP_DIR}/loki-config.yaml (retention: ${LOKI_RETENTION})"
# Based on the upstream default from grafana/docker-otel-lgtm (docker/loki-config.yaml)
# with data retention enabled. The upstream image ships Loki with NO retention,
# so logs grow forever.
$SUDO tee "${APP_DIR}/loki-config.yaml" > /dev/null <<EOF
auth_enabled: false

server:
  http_listen_port: 3100

common:
  instance_addr: 127.0.0.1
  path_prefix: /data/loki
  storage:
    filesystem:
      chunks_directory: /data/loki/chunks
      rules_directory: /data/loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://127.0.0.1:9093

pattern_ingester:
  lifecycler:
    min_ready_duration: 1s

ingester:
  lifecycler:
    min_ready_duration: 1s

frontend:
  scheduler_dns_lookup_period: 1s
  address: 127.0.0.1

query_scheduler:
  use_scheduler_ring: false

limits_config:
  retention_period: ${LOKI_RETENTION}

compactor:
  working_directory: /data/loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
  delete_request_store: filesystem
EOF

echo "===> Generating ${APP_DIR}/tempo-config.yaml (retention: ${TEMPO_RETENTION})"
# Based on the upstream default from grafana/docker-otel-lgtm (docker/tempo-config.yaml)
# with explicit trace retention. Retention is set in overrides.defaults.compaction
# (valid in Tempo 2.x and 3.x): Tempo 3 removed the top-level "compactor" block and
# parses the config strictly, so an unknown block makes it fail to start.
$SUDO tee "${APP_DIR}/tempo-config.yaml" > /dev/null <<EOF
server:
  http_listen_port: 3200
  grpc_listen_port: 9096

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: "127.0.0.1:4417"
        http:
          endpoint: "127.0.0.1:4418"

memberlist:
  bind_addr: [127.0.0.1]
  bind_port: 7947

querier:
  frontend_worker:
    frontend_address: 127.0.0.1:9096

storage:
  trace:
    backend: local
    wal:
      path: /data/tempo/wal
    local:
      path: /data/tempo/blocks

metrics_generator:
  processor:
    span_metrics:
      dimensions:
        - service_name
        - operation
        - status_code
  storage:
    path: /data/tempo/generator/wal
    remote_write:
      - url: http://127.0.0.1:9090/api/v1/write
        send_exemplars: true

overrides:
  defaults:
    metrics_generator:
      processors: [service-graphs, span-metrics]
    compaction:
      block_retention: ${TEMPO_RETENTION}
EOF

# Keep a copy of this script in APP_DIR so future updates are just:
#   bash /opt/otel-lgtm/update-lgtm.sh
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SELF="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  if [ "$SELF" != "${APP_DIR}/update-lgtm.sh" ]; then
    $SUDO cp "$SELF" "${APP_DIR}/update-lgtm.sh"
    $SUDO chmod +x "${APP_DIR}/update-lgtm.sh"
  fi
fi

# Version running now (empty on first install), used for the Grafana backup and
# the rollback instructions below
PREV_IMAGE_ID=$(docker inspect otel-lgtm --format '{{.Image}}' 2>/dev/null || true)
PREV_VERSION=""
if [ -n "$PREV_IMAGE_ID" ]; then
  PREV_VERSION=$(docker image inspect "$PREV_IMAGE_ID" --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^LGTM_VERSION=v\{0,1\}//p') || true
fi

if [ "$PURGE_LOKI" = true ]; then
  echo "===> EMERGENCY: purging ALL stored logs (${DATA_ROOT}/loki)"
  echo "     Traces, metrics and dashboards are NOT touched."
  docker compose -f "$COMPOSE_FILE" down || true
  $SUDO rm -rf "${DATA_ROOT}/loki"
fi

echo "===> Pulling latest image"
docker compose -f "$COMPOSE_FILE" pull
NEW_IMAGE_ID=$(docker image inspect "$IMAGE" --format '{{.Id}}')
IMAGE_CHANGED=false
if [ -n "$PREV_IMAGE_ID" ] && [ "$PREV_IMAGE_ID" != "$NEW_IMAGE_ID" ]; then
  IMAGE_CHANGED=true
fi

echo "===> Checking swap"
if [ "$SWAP_SIZE_GB" -eq 0 ] || [ "$(uname -s)" != "Linux" ] || ! command -v swapon >/dev/null 2>&1; then
  echo "     Skipped"
elif [ -n "$(swapon --show --noheadings 2>/dev/null)" ]; then
  echo "     Swap already active"
else
  SWAP_CREATED=false
  if [ ! -f /swapfile ]; then
    FREE_KB=$(df -Pk / | awk 'NR==2 {print $4}')
    # Never create it on a nearly full disk: keep at least 5 GB free for data
    if [ "$FREE_KB" -ge $(( (SWAP_SIZE_GB + 5) * 1024 * 1024 )) ]; then
      if $SUDO fallocate -l "${SWAP_SIZE_GB}G" /swapfile && $SUDO chmod 600 /swapfile && $SUDO mkswap /swapfile > /dev/null; then
        SWAP_CREATED=true
      else
        $SUDO rm -f /swapfile
      fi
    else
      echo "     WARNING: less than $((SWAP_SIZE_GB + 5))G free on /; not creating swap"
    fi
  fi
  if [ -f /swapfile ] && $SUDO swapon /swapfile; then
    grep -qE '^/swapfile[[:space:]]' /etc/fstab || echo '/swapfile none swap sw 0 0' | $SUDO tee -a /etc/fstab > /dev/null
    # Use swap only under memory pressure
    echo 'vm.swappiness=10' | $SUDO tee /etc/sysctl.d/99-otel-lgtm.conf > /dev/null || true
    $SUDO sysctl -q -w vm.swappiness=10 || true
    echo "     Swap enabled: /swapfile ($(du -h /swapfile | cut -f1))"
  elif [ -f /swapfile ]; then
    echo "     WARNING: could not enable /swapfile; continuing without swap"
    if [ "$SWAP_CREATED" = true ]; then
      $SUDO rm -f /swapfile
    fi
  fi
fi

# A newer Grafana migrates its database on startup and can't be rolled back without
# a copy of it. The stack is stopped only now, after the pull, to keep downtime short.
if [ "$IMAGE_CHANGED" = true ] && [ -d "${DATA_ROOT}/grafana" ]; then
  echo "===> New image version: backing up Grafana data to ${DATA_ROOT}/grafana.bak"
  GRAFANA_KB=$($SUDO du -sk "${DATA_ROOT}/grafana" | cut -f1)
  FREE_KB=$(df -Pk "$DATA_ROOT" | awk 'NR==2 {print $4}')
  if [ "$FREE_KB" -gt $((GRAFANA_KB * 2)) ]; then
    docker compose -f "$COMPOSE_FILE" stop
    $SUDO rm -rf "${DATA_ROOT}/grafana.bak"
    $SUDO cp -a "${DATA_ROOT}/grafana" "${DATA_ROOT}/grafana.bak"
  else
    echo "     WARNING: not enough free disk for the backup; skipping it"
  fi
fi

echo "===> Recreating the stack"
# --force-recreate also resets the container's old json log file
docker compose -f "$COMPOSE_FILE" up -d --force-recreate

echo "===> Waiting for the stack to become healthy (up to 5 min)"
# The image has its own HEALTHCHECK. A component that fails to start makes the
# container exit, and restart: unless-stopped turns that into a restart loop.
RUN_STATUS="" RESTARTS=0 HEALTH=""
for _ in $(seq 1 60); do
  read -r RUN_STATUS RESTARTS HEALTH <<< "$(docker inspect otel-lgtm --format '{{.State.Status}} {{.RestartCount}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' 2>/dev/null || echo "missing 0 none")"
  if [ "$HEALTH" = healthy ] || [ "$HEALTH" = none ] || [ "$RUN_STATUS" != running ] || [ "$RESTARTS" -gt 0 ]; then
    break
  fi
  sleep 5
done

if [ "$HEALTH" != healthy ] && { [ "$HEALTH" != none ] || [ "$RUN_STATUS" != running ]; }; then
  echo ""
  echo "============================================"
  echo "===> ERROR: the stack is not healthy (status=${RUN_STATUS} health=${HEALTH} restarts=${RESTARTS})"
  echo "============================================"
  docker logs --tail 500 otel-lgtm 2>&1 | grep -E 'exited before|failed parsing|not found in type|level=error' | tail -15 || true
  if [ "$RUN_STATUS" = running ] && [ "$RESTARTS" -eq 0 ]; then
    echo ""
    echo "It may just be slow to start: check again in a few minutes with"
    echo "  docker ps --filter name=otel-lgtm   (wait for \"(healthy)\")"
  fi
  if [ "$IMAGE_CHANGED" = true ] && [ -n "$PREV_VERSION" ]; then
    echo ""
    echo "To roll back to the previous version (${PREV_VERSION}):"
    echo "  cd ${APP_DIR} && docker compose down"
    if [ -d "${DATA_ROOT}/grafana.bak" ]; then
      echo "  rm -rf ${DATA_ROOT}/grafana && cp -a ${DATA_ROOT}/grafana.bak ${DATA_ROOT}/grafana"
    fi
    echo "  sed -i 's|${IMAGE}|grafana/otel-lgtm:${PREV_VERSION}|' compose.yaml && docker compose up -d"
  fi
  exit 1
fi

echo "===> Removing dangling (old) images"
docker image prune -f

echo ""
echo "============================================"
echo "===> Update complete!"
echo "============================================"
echo ""
echo "Retention: logs=${LOKI_RETENTION} | traces=${TEMPO_RETENTION} | metrics=${PROMETHEUS_RETENTION}"
echo "Note: Loki cleanup is not instant - the compactor deletes old data"
echo "gradually (retention_delete_delay: 2h). Disk space frees over a few hours."
if [ "$IMAGE_CHANGED" = true ]; then
  echo "New version: Grafana keeps updating its plugins in the background for a"
  echo "few minutes, so some panels may show errors until it finishes."
fi
echo ""
docker compose -f "$COMPOSE_FILE" ps
echo ""
df -h / | tail -2
