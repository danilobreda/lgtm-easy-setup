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
- Executa `update-lgtm.sh`, que **gera** `compose.yaml` + configs de retenção em `/opt/otel-lgtm` e executa `docker compose pull && up -d`
- Deixa uma cópia de `update-lgtm.sh` em `/opt/otel-lgtm` para atualizações futuras
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

A imagem `grafana/otel-lgtm` **não vem com retenção configurada para o Loki** (logs crescem para sempre e enchem o disco). O `update-lgtm.sh` gera configs customizadas que são montadas no container para habilitar limpeza automática:

| Sinal | Componente | Retenção | Arquivo gerado |
|-------|-----------|----------|----------------|
| Logs | Loki | **30 dias** | `loki-config.yaml` (`retention_period` + compactor) |
| Traces | Tempo | **15 dias** | `tempo-config.yaml` (`block_retention: 360h`) |
| Métricas | Prometheus | **30 dias** | `compose.yaml` (`PROMETHEUS_EXTRA_ARGS=--storage.tsdb.retention.time=30d`) |
| Logs do próprio container | Docker | máx. ~150 MB | `compose.yaml` (`logging: max-size: 50m, max-file: 3`) |

> 💡 Para mudar a janela de retenção, edite as variáveis `LOKI_RETENTION`, `TEMPO_RETENTION` e `PROMETHEUS_RETENTION` no topo do `update-lgtm.sh` e rode ele novamente.

> ℹ️ A exclusão do Loki não é imediata: o compactor marca os dados antigos e apaga após `retention_delete_delay` (2h). O espaço em disco é liberado gradualmente.

> ℹ️ Pyroscope (profiling) não tem retenção por tempo configurada, mas só cresce se você enviar dados de profiling; ele também possui limpeza de emergência quando o disco está quase cheio.

## 🔄 Como Atualizar

O `update-lgtm.sh` regenera todas as configs, baixa a imagem mais recente e recria o container — **sem perder seus dados**. Ele também:

- **Cria uma swap de 4 GB** em `/swapfile` se o servidor não tiver nenhuma. Sem swap, um pico de memória faz o kernel matar o Prometheus e as métricas param sem aviso. Só cria se sobrarem 5 GB livres no disco. Para mudar o tamanho ou desligar (`0`), edite `SWAP_SIZE_GB` no topo do script.
- **Faz backup do Grafana** (`/data/otel-lgtm/grafana` → `/data/otel-lgtm/grafana.bak`) quando a versão da imagem muda. O Grafana novo migra o banco e não volta para a versão antiga sem essa cópia.
- **Espera até 5 min a stack ficar `healthy`.** Se não ficar, mostra o erro, sai com código 1 e imprime os comandos para voltar à versão anterior.

Rode direto da internet (não precisa clonar nada, nem ocupa disco):

```bash
curl -fsSL https://raw.githubusercontent.com/danilobreda/lgtm-easy-setup/main/update-lgtm.sh | bash
```

Ou, se já instalou antes, uma cópia fica salva no servidor:

```bash
bash /opt/otel-lgtm/update-lgtm.sh
```

### Disco cheio? Diagnóstico rápido

```bash
# Quem está ocupando o disco?
sudo du -sh /data/otel-lgtm/*

# Logs do próprio container Docker (sem limite por padrão em versões antigas deste setup)
sudo du -sh /var/lib/docker/containers/*
```

Se `/data/otel-lgtm/loki` for o vilão, após rodar o `update-lgtm.sh` o compactor vai limpar tudo com mais de 30 dias automaticamente (aguarde algumas horas — a exclusão é gradual).

**Emergência** (disco 100% cheio e você aceita perder os logs antigos — traces, métricas e dashboards ficam intactos):

```bash
curl -fsSL https://raw.githubusercontent.com/danilobreda/lgtm-easy-setup/main/update-lgtm.sh | bash -s -- --purge-loki
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
