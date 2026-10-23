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
- Runs `update-lgtm.sh`, which **generates** `compose.yaml` + retention configs in `/opt/otel-lgtm` and runs `docker compose pull && up -d`
- Leaves a copy of `update-lgtm.sh` in `/opt/otel-lgtm` for future updates
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

The `grafana/otel-lgtm` image **ships with no retention configured for Loki** (logs grow forever and fill the disk). `update-lgtm.sh` generates custom configs that are mounted into the container to enable automatic cleanup:

| Signal | Component | Retention | Generated file |
|--------|-----------|-----------|----------------|
| Logs | Loki | **30 days** | `loki-config.yaml` (`retention_period` + compactor) |
| Traces | Tempo | **15 days** | `tempo-config.yaml` (`block_retention: 360h`) |
| Metrics | Prometheus | **30 days** | `compose.yaml` (`PROMETHEUS_EXTRA_ARGS=--storage.tsdb.retention.time=30d`) |
| Container's own logs | Docker | max ~150 MB | `compose.yaml` (`logging: max-size: 50m, max-file: 3`) |

> 💡 To change the retention window, edit the `LOKI_RETENTION`, `TEMPO_RETENTION` and `PROMETHEUS_RETENTION` variables at the top of `update-lgtm.sh` and run it again.

> ℹ️ Loki deletion is not instant: the compactor marks old data and deletes it after `retention_delete_delay` (2h). Disk space is freed gradually.

> ℹ️ Pyroscope (profiling) has no time-based retention configured, but it only grows if you send profiling data; it also has emergency cleanup when the disk is nearly full.

## 🔄 How to Update

`update-lgtm.sh` regenerates all configs, pulls the latest image and recreates the container — **without losing your data**. It also:

- **Creates a 4 GB swap file** at `/swapfile` if the host has none. Without swap, a memory spike makes the kernel kill Prometheus and metrics stop silently. It is only created if 5 GB of disk stay free. To change the size or disable it (`0`), edit `SWAP_SIZE_GB` at the top of the script.
- **Backs up Grafana** (`/data/otel-lgtm/grafana` → `/data/otel-lgtm/grafana.bak`) when the image version changes. A newer Grafana migrates its database and can't go back to the old version without this copy.
- **Waits up to 5 min for the stack to become `healthy`.** If it doesn't, it shows the error, exits with code 1 and prints the commands to roll back to the previous version.

Run it straight from the internet (no cloning needed, uses no disk space):

```bash
curl -fsSL https://raw.githubusercontent.com/danilobreda/lgtm-easy-setup/main/update-lgtm.sh | bash
```

Or, if you installed before, a copy is kept on the server:

```bash
bash /opt/otel-lgtm/update-lgtm.sh
```

### Disk full? Quick diagnosis

```bash
# What is eating the disk?
sudo du -sh /data/otel-lgtm/*

# The container's own Docker logs (unbounded by default in older versions of this setup)
sudo du -sh /var/lib/docker/containers/*
```

If `/data/otel-lgtm/loki` is the culprit, after running `update-lgtm.sh` the compactor will automatically clean everything older than 30 days (allow a few hours — deletion is gradual).

**Emergency** (disk 100% full and you accept losing old logs — traces, metrics and dashboards stay intact):

```bash
curl -fsSL https://raw.githubusercontent.com/danilobreda/lgtm-easy-setup/main/update-lgtm.sh | bash -s -- --purge-loki
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
