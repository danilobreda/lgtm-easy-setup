# lgtm-easy-setup

Script to deploy the LGTM stack (Loki, Grafana, Tempo, Prometheus + OpenTelemetry Collector) using the grafana/otel-lgtm:latest image with persistent data storage and automatic data retention (30 days for logs/metrics, 15 days for traces)

## 📖 Documentation / Documentação

- 🇺🇸 **[English](docs/README_EN.md)**
- 🇧🇷 **[Português](docs/README_PT.md)**

## ⚠️ Requirements / Requisitos

- **Ubuntu 22.04 LTS** only / apenas

## 🚀 Quick Start / Início Rápido

```bash
git clone https://github.com/danilobreda/lgtm-easy-setup.git
cd lgtm-easy-setup
chmod +x install-lgtm.sh
./install-lgtm.sh
```

## 🔄 Quick Update / Atualização Rápida

Updates the stack and applies retention configs, without losing data. It also creates a 4 GB swap file if the host has none, backs up Grafana before a version change and waits until the stack is healthy / Atualiza a stack e aplica as configs de retenção, sem perder dados. Também cria uma swap de 4 GB se o servidor não tiver, faz backup do Grafana antes de trocar de versão e espera a stack ficar saudável:

```bash
curl -fsSL https://raw.githubusercontent.com/danilobreda/lgtm-easy-setup/main/update-lgtm.sh -o /tmp/update-lgtm.sh
bash /tmp/update-lgtm.sh
```

Step by step, with checks and what to expect / Passo a passo, com conferências e o que esperar: [English](docs/README_EN.md#-how-to-update) · [Português](docs/README_PT.md#-como-atualizar)

Disk 100% full? Purges all stored logs (traces/metrics/dashboards stay intact) / Disco 100% cheio? Apaga todos os logs armazenados (traces/métricas/dashboards ficam intactos):

```bash
curl -fsSL https://raw.githubusercontent.com/danilobreda/lgtm-easy-setup/main/update-lgtm.sh | bash -s -- --purge-loki
```

## 📁 Where is my data? / Onde ficam meus dados?

| Path / Caminho | Description / Descrição |
|----------------|-------------------------|
| `/data/otel-lgtm` | Persistent data / Dados persistentes |
| `/opt/otel-lgtm` | Application files / Arquivos da aplicação |

## 🗑️ Data Retention / Retenção de Dados

| Signal / Sinal | Retention / Retenção |
|----------------|----------------------|
| Logs (Loki) | 30 days / dias |
| Metrics / Métricas (Prometheus) | 30 days / dias |
| Traces (Tempo) | 15 days / dias |

## License / Licença

MIT
