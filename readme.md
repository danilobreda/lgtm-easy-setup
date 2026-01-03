# lgtm-easy-setup

🌐 **[English](#english)** | **[Português](#português)**

---

## English

Idempotent script to deploy the LGTM stack (Loki, Grafana, Tempo, Mimir) using the `grafana/otel-lgtm:latest` image with persistent data storage.

UBUNTU only at this version.

### Quick Start

```bash
git clone https://github.com/danilobreda/lgtm-easy-setup.git
cd lgtm-easy-setup
chmod +x install-lgtm.sh
./install-lgtm.sh
```

### What It Does

- Updates packages and installs Docker + Docker Compose v2
- Adds your user to the `docker` group
- Creates `/opt/otel-lgtm` directory and optionally clones/updates the upstream repo
- Creates `/data/otel-lgtm` (persistence) with `chown 472:472` (typical Grafana image UID)
- Copies `compose.yaml` to `/opt/otel-lgtm` and runs `docker compose pull && up -d`
- **Self-cleans:** removes `compose.yaml`, `readme.md`, and `install-lgtm.sh` from the cloned directory
- Shows `ls -la` and `docker compose ps` to confirm installation

### 📁 Data Storage

| Path | Description |
|------|-------------|
| `/data/otel-lgtm` | **All persistent data** (Grafana dashboards, Loki logs, Tempo traces, Mimir metrics) |
| `/opt/otel-lgtm` | Application files and `compose.yaml` |

> ⚠️ **Important:** The `/data/otel-lgtm` directory is owned by UID `472` (Grafana user). **Do not delete this folder** or you will lose all your data!

### 🔄 Auto-Restart Behavior

The container is configured with `restart: unless-stopped`, which means:

| Scenario | Behavior |
|----------|----------|
| Server/host reboot | ✅ **Automatically restarts** |
| Docker daemon restart | ✅ **Automatically restarts** |
| Container crash | ✅ **Automatically restarts** |
| Manual `docker compose down` | ❌ **Stays stopped** (until you run `up -d` again) |
| Manual `docker stop` | ❌ **Stays stopped** (until next Docker restart or manual start) |

### 🔄 How to Update

To update to the latest version of the LGTM image:

```bash
cd lgtm-easy-setup
./install-lgtm.sh
```

Or manually:

```bash
docker compose -f /opt/otel-lgtm/compose.yaml pull
docker compose -f /opt/otel-lgtm/compose.yaml up -d
```

> 💡 The script is **idempotent** - you can run it multiple times safely. It will pull the latest image and recreate the container if needed, **without losing your data**.

### Exposed Ports

| Port | Service |
|------|---------|
| `3000` | Grafana UI |
| `4317` | OTLP gRPC receiver |
| `4318` | OTLP HTTP receiver |

### Operations

```bash
# Start/update stack
./install-lgtm.sh

# View logs
docker compose -f /opt/otel-lgtm/compose.yaml logs -f

# Stop stack (data is preserved)
docker compose -f /opt/otel-lgtm/compose.yaml down

# Restart stack
docker compose -f /opt/otel-lgtm/compose.yaml restart

# Check status
docker compose -f /opt/otel-lgtm/compose.yaml ps
```

### Backup

To backup your data:

```bash
sudo tar -czvf otel-lgtm-backup-$(date +%Y%m%d).tar.gz /data/otel-lgtm
```

---

## Português

Script idempotente para subir o stack LGTM (Loki, Grafana, Tempo, Mimir) usando a imagem `grafana/otel-lgtm:latest` com armazenamento persistente de dados.

### Uso Rápido

```bash
git clone https://github.com/danilobreda/lgtm-easy-setup.git
cd lgtm-easy-setup
chmod +x install-lgtm.sh
./install-lgtm.sh
```

### O Que o Script Faz

- Atualiza pacotes e instala Docker + Docker Compose v2
- Adiciona seu usuário ao grupo `docker`
- Cria o diretório `/opt/otel-lgtm` e opcionalmente clona/atualiza o repositório upstream
- Cria `/data/otel-lgtm` (persistência) com `chown 472:472` (UID típico da imagem Grafana)
- Copia `compose.yaml` para `/opt/otel-lgtm` e executa `docker compose pull && up -d`
- **Auto-limpeza:** remove `compose.yaml`, `readme.md` e `install-lgtm.sh` do diretório clonado
- Exibe `ls -la` e `docker compose ps` para confirmar a instalação

### 📁 Armazenamento de Dados

| Caminho | Descrição |
|---------|-----------|
| `/data/otel-lgtm` | **Todos os dados persistentes** (dashboards do Grafana, logs do Loki, traces do Tempo, métricas do Mimir) |
| `/opt/otel-lgtm` | Arquivos da aplicação e `compose.yaml` |

> ⚠️ **Importante:** O diretório `/data/otel-lgtm` pertence ao UID `472` (usuário do Grafana). **Não delete esta pasta** ou você perderá todos os seus dados!

### 🔄 Comportamento de Reinicialização

O container está configurado com `restart: unless-stopped`, o que significa:

| Cenário | Comportamento |
|---------|---------------|
| Reboot do servidor/host | ✅ **Reinicia automaticamente** |
| Reinício do daemon Docker | ✅ **Reinicia automaticamente** |
| Crash do container | ✅ **Reinicia automaticamente** |
| `docker compose down` manual | ❌ **Fica parado** (até você executar `up -d` novamente) |
| `docker stop` manual | ❌ **Fica parado** (até próximo restart do Docker ou start manual) |

### 🔄 Como Atualizar

Para atualizar para a última versão da imagem LGTM:

```bash
cd lgtm-easy-setup
./install-lgtm.sh
```

Ou manualmente:

```bash
docker compose -f /opt/otel-lgtm/compose.yaml pull
docker compose -f /opt/otel-lgtm/compose.yaml up -d
```

> 💡 O script é **idempotente** - você pode executá-lo várias vezes sem problemas. Ele vai baixar a imagem mais recente e recriar o container se necessário, **sem perder seus dados**.

### Portas Expostas

| Porta | Serviço |
|-------|---------|
| `3000` | Interface do Grafana |
| `4317` | Receptor OTLP gRPC |
| `4318` | Receptor OTLP HTTP |

### Operações

```bash
# Iniciar/atualizar stack
./install-lgtm.sh

# Ver logs
docker compose -f /opt/otel-lgtm/compose.yaml logs -f

# Parar stack (dados são preservados)
docker compose -f /opt/otel-lgtm/compose.yaml down

# Reiniciar stack
docker compose -f /opt/otel-lgtm/compose.yaml restart

# Verificar status
docker compose -f /opt/otel-lgtm/compose.yaml ps
```

### Backup

Para fazer backup dos seus dados:

```bash
sudo tar -czvf otel-lgtm-backup-$(date +%Y%m%d).tar.gz /data/otel-lgtm
```

---

## License / Licença

MIT
