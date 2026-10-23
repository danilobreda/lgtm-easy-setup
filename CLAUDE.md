# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Two bash scripts that deploy and update the Grafana LGTM observability stack (Loki, Grafana, Tempo, Prometheus + OTel Collector) on Ubuntu servers, using the single-container `grafana/otel-lgtm:latest` image from https://github.com/grafana/docker-otel-lgtm. Docs are bilingual (PT/EN in `docs/`; the root `readme.md` mixes both).

## Architecture — the key design decision

**No YAML files live in git.** `update-lgtm.sh` generates all three config files (`compose.yaml`, `loki-config.yaml`, `tempo-config.yaml`) via heredocs into `/opt/otel-lgtm` on the target server. This is intentional (owner's preference): the update flow must work via `curl | bash` on a server with a 100% full disk, without cloning anything. Do not reintroduce standalone YAML files.

- `install-lgtm.sh` — first-time server setup (Docker install, `/opt/otel-lgtm` app dir, `/data/otel-lgtm` data dir owned by UID 472). Delegates config generation and stack startup to `update-lgtm.sh`, then self-deletes its own clone directory (that `rm -rf "${SCRIPT_DIR}"` must stay last).
- `update-lgtm.sh` — idempotent; regenerates configs, `docker compose pull` + `up -d --force-recreate`, and copies itself to `/opt/otel-lgtm/update-lgtm.sh`. Supports `--purge-loki` (emergency: deletes all stored logs when the disk is full). Around the restart it also: creates `/swapfile` when the host has no swap (`SWAP_SIZE_GB`, needs 5 GB free disk), copies `grafana/` to `grafana.bak` when the image ID changes (Grafana DB migrations are one-way), and waits for the image's HEALTHCHECK — on failure it exits 1 with rollback commands and skips `docker image prune`.

## Data retention — why the custom configs exist

The upstream image ships Loki with **no retention at all** (this once filled a 100GB production disk). The generated configs override upstream defaults, mounted into the container at `/otel-lgtm/<name>.yaml` (the image's official override mechanism):

- Retention windows are variables at the top of `update-lgtm.sh`: `LOKI_RETENTION=720h` (logs, 30d), `TEMPO_RETENTION=360h` (traces, 15d), `PROMETHEUS_RETENTION=30d` (metrics, via `PROMETHEUS_EXTRA_ARGS`).
- The Loki/Tempo heredocs are the **upstream defaults from `docker-otel-lgtm/docker/*.yaml` plus the retention blocks**. When updating them, re-check the upstream files first — ports, paths and schema in the base config must match the image version.
- The image is `latest`, so a new upstream release can bring a major component version. Tempo 3 parses its config strictly (`yaml.UnmarshalStrict`): an unknown block (like the old top-level `compactor:`) stops Tempo, and the image's `run-all.sh` then exits the whole container. Before shipping a config change, run the generated configs against the current image with Docker.
- The compose heredoc also caps the container's own Docker json log (`max-size: 50m, max-file: 3`) because `ENABLE_LOGS_ALL=true` makes stdout grow fast. Keep this.

## Testing changes (no CI, no test suite)

Scripts target Ubuntu but are developed on Windows (Git Bash has no `sudo` — the `SUDO` detection in `update-lgtm.sh` handles this). To verify locally:

```bash
bash -n update-lgtm.sh   # syntax check

# Run the generation part for real against a scratch dir, then validate:
sed -e 's|^APP_DIR="/opt/otel-lgtm"|APP_DIR="'$PWD'/testrun"|' \
    -e '/^echo "===> Pulling latest image"/,$d' update-lgtm.sh > /tmp/test-update.sh
bash /tmp/test-update.sh
docker compose -f testrun/compose.yaml config --quiet
```

## Docs to keep in sync

Any change to retention values, flags, or the update flow must be reflected in three places: `readme.md` (Quick Update section + retention table), `docs/README_PT.md`, and `docs/README_EN.md` (these two mirror each other section-by-section).
