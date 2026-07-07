# lgtm-easy-setup - Documentação em Português

## Uso Rápido

```bash
git clone https://github.com/danilobreda/lgtm-easy-setup.git
cd lgtm-easy-setup
chmod +x install-lgtm.sh
./install-lgtm.sh
```

## O Que o Script Faz

- Verifica se está rodando no Ubuntu 22.04 (sai se não estiver)
- Atualiza pacotes e instala Docker + Docker Compose v2
- Adiciona seu usuário ao grupo `docker`
- Cria o diretório `/opt/otel-lgtm` e opcionalmente clona/atualiza o repositório upstream
- Cria `/data/otel-lgtm` (persistência) com `chown 472:472` (UID típico da imagem Grafana)
- Copia `compose.yaml` para `/opt/otel-lgtm` e executa `docker compose pull && up -d`
- **Auto-limpeza:** remove o diretório clonado após a instalação
- Exibe `ls -la` e `docker compose ps` para confirmar a instalação

## 📁 Armazenamento de Dados

| Caminho | Descrição |
|---------|-----------|
| `/data/otel-lgtm` | **Todos os dados persistentes** (dashboards do Grafana, logs do Loki, traces do Tempo, métricas do Prometheus) |
| `/opt/otel-lgtm` | Arquivos da aplicação e `compose.yaml` |

> ⚠️ **Importante:** O diretório `/data/otel-lgtm` pertence ao UID `472` (usuário do Grafana). **Não delete esta pasta** ou você perderá todos os seus dados!

## 🔄 Comportamento de Reinicialização

O container está configurado com `restart: unless-stopped`, o que significa:

| Cenário | Comportamento |
|---------|---------------|
| Reboot do servidor/host | ✅ **Reinicia automaticamente** |
| Reinício do daemon Docker | ✅ **Reinicia automaticamente** |
| Crash do container | ✅ **Reinicia automaticamente** |
| `docker compose down` manual | ❌ **Fica parado** (até você executar `up -d` novamente) |
| `docker stop` manual | ❌ **Fica parado** (até próximo restart do Docker ou start manual) |

## 🗑️ Retenção de Dados (limpeza automática)

A imagem `grafana/otel-lgtm` **não vem com retenção configurada para o Loki** (logs crescem para sempre e enchem o disco). Este projeto monta configs customizadas no container para habilitar limpeza automática:

| Sinal | Componente | Retenção | Onde é configurado |
|-------|-----------|----------|--------------------|
| Logs | Loki | **30 dias** | `loki-config.yaml` (`retention_period` + compactor) |
| Traces | Tempo | **15 dias** | `tempo-config.yaml` (`block_retention: 360h`) |
| Métricas | Prometheus | **30 dias** | `compose.yaml` (`PROMETHEUS_EXTRA_ARGS=--storage.tsdb.retention.time=30d`) |
| Logs do próprio container | Docker | máx. ~150 MB | `compose.yaml` (`logging: max-size: 50m, max-file: 3`) |

> 💡 Para mudar a janela de retenção, edite os valores acima e rode `docker compose -f /opt/otel-lgtm/compose.yaml up -d --force-recreate`.

> ℹ️ A exclusão do Loki não é imediata: o compactor marca os dados antigos e apaga após `retention_delete_delay` (2h). O espaço em disco é liberado gradualmente.

> ℹ️ Pyroscope (profiling) não tem retenção por tempo configurada, mas só cresce se você enviar dados de profiling; ele também possui limpeza de emergência quando o disco está quase cheio.

## 🔄 Como Atualizar

Para atualizar para a última versão da imagem LGTM (e aplicar as configs de retenção):

```bash
# 1. Baixe a versão mais recente deste repositório
git clone https://github.com/danilobreda/lgtm-easy-setup.git /tmp/lgtm-easy-setup

# 2. Copie o compose e as configs de retenção para o diretório da aplicação
cp /tmp/lgtm-easy-setup/compose.yaml /opt/otel-lgtm/compose.yaml
cp /tmp/lgtm-easy-setup/loki-config.yaml /opt/otel-lgtm/loki-config.yaml
cp /tmp/lgtm-easy-setup/tempo-config.yaml /opt/otel-lgtm/tempo-config.yaml
rm -rf /tmp/lgtm-easy-setup

# 3. Atualize a imagem e recrie o container
docker compose -f /opt/otel-lgtm/compose.yaml pull
docker compose -f /opt/otel-lgtm/compose.yaml up -d --force-recreate
```

> 💡 O processo de atualização vai baixar a imagem mais recente e recriar o container se necessário, **sem perder seus dados**.

### Disco cheio? Diagnóstico rápido

```bash
# Quem está ocupando o disco?
sudo du -sh /data/otel-lgtm/*

# Logs do próprio container Docker (sem limite por padrão em versões antigas deste setup)
sudo du -sh /var/lib/docker/containers/*
```

Se `/data/otel-lgtm/loki` for o vilão, após aplicar a atualização acima o compactor vai limpar tudo com mais de 30 dias automaticamente (aguarde algumas horas). **Emergência** (se o disco está 100% cheio e você aceita perder os logs antigos):

```bash
docker compose -f /opt/otel-lgtm/compose.yaml down
sudo rm -rf /data/otel-lgtm/loki   # apaga TODOS os logs (traces/métricas/dashboards ficam intactos)
docker compose -f /opt/otel-lgtm/compose.yaml up -d
```

## Portas Expostas

| Porta | Serviço |
|-------|---------|
| `3000` | Interface do Grafana |
| `4317` | Receptor OTLP gRPC |
| `4318` | Receptor OTLP HTTP |

## Operações

```bash
# Ver logs
docker compose -f /opt/otel-lgtm/compose.yaml logs -f

# Parar stack (dados são preservados)
docker compose -f /opt/otel-lgtm/compose.yaml down

# Reiniciar stack
docker compose -f /opt/otel-lgtm/compose.yaml restart

# Verificar status
docker compose -f /opt/otel-lgtm/compose.yaml ps
```

## Backup

Para fazer backup dos seus dados:

```bash
sudo tar -czvf otel-lgtm-backup-$(date +%Y%m%d).tar.gz /data/otel-lgtm
```
