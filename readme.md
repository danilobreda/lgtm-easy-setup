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
