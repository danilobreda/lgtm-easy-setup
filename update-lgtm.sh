#!/usr/bin/env bash
set -euo pipefail

# update-lgtm.sh
# (Re)generates all config files (compose.yaml, loki-config.yaml, tempo-config.yaml)
# and updates the LGTM stack to the latest image. Safe to re-run at any time.
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

# --- Retention windows (edit here if you need different values) ---
LOKI_RETENTION="720h"       # logs: 30 days
TEMPO_RETENTION="360h"      # traces: 15 days
PROMETHEUS_RETENTION="30d"  # metrics: 30 days

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
    image: grafana/otel-lgtm:latest
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
# with explicit trace retention.
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

compactor:
  compaction:
    block_retention: ${TEMPO_RETENTION}

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

if [ "$PURGE_LOKI" = true ]; then
  echo "===> EMERGENCY: purging ALL stored logs (${DATA_ROOT}/loki)"
  echo "     Traces, metrics and dashboards are NOT touched."
  docker compose -f "$COMPOSE_FILE" down || true
  $SUDO rm -rf "${DATA_ROOT}/loki"
fi

echo "===> Pulling latest image"
docker compose -f "$COMPOSE_FILE" pull

echo "===> Recreating the stack"
# --force-recreate also resets the container's old json log file
docker compose -f "$COMPOSE_FILE" up -d --force-recreate

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
echo ""
docker compose -f "$COMPOSE_FILE" ps
echo ""
df -h / | tail -2
