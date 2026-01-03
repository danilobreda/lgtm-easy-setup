# lgtm-easy-setup

Script idempotente para subir o stack LGTM (imagem `grafana/otel-lgtm:latest`) com dados persistentes em `/data/otel-lgtm`. Sem systemd/autostart.

## Uso rápido
```bash
git clone https://github.com/danilobreda/lgtm-easy-setup.git
cd lgtm-easy-setup
chmod +x install-lgtm.sh
./install-lgtm.sh
```

## O que acontece
- Atualiza pacotes, instala Docker e docker compose v2.
- Adiciona seu usuário ao grupo `docker`.
- Garante `/opt/otel-lgtm` e opcionalmente clona/atualiza o repo upstream.
- Cria `/data/otel-lgtm` (persistência) e aplica `chown` 472:472 (uid típico da imagem Grafana).
- Copia `compose.yaml` para `/opt/otel-lgtm` e roda `docker compose pull && up -d`.

## Operações
- Subir/atualizar: `./install-lgtm.sh`
- Logs: `docker compose -f /opt/otel-lgtm/compose.yaml logs -f`
- Parar: `docker compose -f /opt/otel-lgtm/compose.yaml down`