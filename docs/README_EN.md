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
| `/data/otel-lgtm` | **All persistent data** (Grafana dashboards, Loki logs, Tempo traces, Mimir metrics) |
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

## 🔄 How to Update

To update to the latest version of the LGTM image:

```bash
docker compose -f /opt/otel-lgtm/compose.yaml pull
docker compose -f /opt/otel-lgtm/compose.yaml up -d
```

> 💡 The update process will pull the latest image and recreate the container if needed, **without losing your data**.

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
