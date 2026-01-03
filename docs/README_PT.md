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
| `/data/otel-lgtm` | **Todos os dados persistentes** (dashboards do Grafana, logs do Loki, traces do Tempo, métricas do Mimir) |
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

## 🔄 Como Atualizar

Para atualizar para a última versão da imagem LGTM:

```bash
docker compose -f /opt/otel-lgtm/compose.yaml pull
docker compose -f /opt/otel-lgtm/compose.yaml up -d
```

> 💡 O processo de atualização vai baixar a imagem mais recente e recriar o container se necessário, **sem perder seus dados**.

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
