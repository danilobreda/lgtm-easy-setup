# lgtm-easy-setup - English Documentation

## Quick Start

```bash
git clone https://github.com/danilobreda/lgtm-easy-setup.git
cd lgtm-easy-setup
chmod +x install-lgtm.sh
./install-lgtm.sh
```

## What It Does

- Checks if running on Ubuntu 22.04 (exits if not)
- Updates packages and installs Docker + Docker Compose v2
- Adds your user to the `docker` group
- Creates `/opt/otel-lgtm` directory and optionally clones/updates the upstream repo
- Creates `/data/otel-lgtm` (persistence) with `chown 472:472` (typical Grafana image UID)
- Copies `compose.yaml` to `/opt/otel-lgtm` and runs `docker compose pull && up -d`
- **Self-cleans:** removes the cloned directory after installation
- Shows `ls -la` and `docker compose ps` to confirm installation

## 📁 Data Storage

| Path | Description |
|------|-------------|
| `/data/otel-lgtm` | **All persistent data** (Grafana dashboards, Loki logs, Tempo traces, Prometheus metrics) |
| `/opt/otel-lgtm` | Application files and `compose.yaml` |

> ⚠️ **Important:** The `/data/otel-lgtm` directory is owned by UID `472` (Grafana user). **Do not delete this folder** or you will lose all your data!

## 🔄 Auto-Restart Behavior

The container is configured with `restart: unless-stopped`, which means:

| Scenario | Behavior |
|----------|----------|
| Server/host reboot | ✅ **Automatically restarts** |
| Docker daemon restart | ✅ **Automatically restarts** |
| Container crash | ✅ **Automatically restarts** |
| Manual `docker compose down` | ❌ **Stays stopped** (until you run `up -d` again) |
| Manual `docker stop` | ❌ **Stays stopped** (until next Docker restart or manual start) |

## 🗑️ Data Retention (automatic cleanup)

The `grafana/otel-lgtm` image **ships with no retention configured for Loki** (logs grow forever and fill the disk). This project mounts custom configs into the container to enable automatic cleanup:

| Signal | Component | Retention | Where it's configured |
|--------|-----------|-----------|-----------------------|
| Logs | Loki | **30 days** | `loki-config.yaml` (`retention_period` + compactor) |
| Traces | Tempo | **15 days** | `tempo-config.yaml` (`block_retention: 360h`) |
| Metrics | Prometheus | **30 days** | `compose.yaml` (`PROMETHEUS_EXTRA_ARGS=--storage.tsdb.retention.time=30d`) |
| Container's own logs | Docker | max ~150 MB | `compose.yaml` (`logging: max-size: 50m, max-file: 3`) |

> 💡 To change the retention window, edit the values above and run `docker compose -f /opt/otel-lgtm/compose.yaml up -d --force-recreate`.

> ℹ️ Loki deletion is not instant: the compactor marks old data and deletes it after `retention_delete_delay` (2h). Disk space is freed gradually.

> ℹ️ Pyroscope (profiling) has no time-based retention configured, but it only grows if you send profiling data; it also has emergency cleanup when the disk is nearly full.

## 🔄 How to Update

To update to the latest version of the LGTM image (and apply the retention configs):

```bash
# 1. Get the latest version of this repository
git clone https://github.com/danilobreda/lgtm-easy-setup.git /tmp/lgtm-easy-setup

# 2. Copy the compose file and retention configs into the app directory
cp /tmp/lgtm-easy-setup/compose.yaml /opt/otel-lgtm/compose.yaml
cp /tmp/lgtm-easy-setup/loki-config.yaml /opt/otel-lgtm/loki-config.yaml
cp /tmp/lgtm-easy-setup/tempo-config.yaml /opt/otel-lgtm/tempo-config.yaml
rm -rf /tmp/lgtm-easy-setup

# 3. Pull the latest image and recreate the container
docker compose -f /opt/otel-lgtm/compose.yaml pull
docker compose -f /opt/otel-lgtm/compose.yaml up -d --force-recreate
```

> 💡 The update process will pull the latest image and recreate the container if needed, **without losing your data**.

### Disk full? Quick diagnosis

```bash
# What is eating the disk?
sudo du -sh /data/otel-lgtm/*

# The container's own Docker logs (unbounded by default in older versions of this setup)
sudo du -sh /var/lib/docker/containers/*
```

If `/data/otel-lgtm/loki` is the culprit, after applying the update above the compactor will automatically clean everything older than 30 days (allow a few hours). **Emergency** (if the disk is 100% full and you accept losing old logs):

```bash
docker compose -f /opt/otel-lgtm/compose.yaml down
sudo rm -rf /data/otel-lgtm/loki   # deletes ALL logs (traces/metrics/dashboards stay intact)
docker compose -f /opt/otel-lgtm/compose.yaml up -d
```

## Exposed Ports

| Port | Service |
|------|---------|
| `3000` | Grafana UI |
| `4317` | OTLP gRPC receiver |
| `4318` | OTLP HTTP receiver |

## Operations

```bash
# View logs
docker compose -f /opt/otel-lgtm/compose.yaml logs -f

# Stop stack (data is preserved)
docker compose -f /opt/otel-lgtm/compose.yaml down

# Restart stack
docker compose -f /opt/otel-lgtm/compose.yaml restart

# Check status
docker compose -f /opt/otel-lgtm/compose.yaml ps
```

## Backup

To backup your data:

```bash
sudo tar -czvf otel-lgtm-backup-$(date +%Y%m%d).tar.gz /data/otel-lgtm
```
