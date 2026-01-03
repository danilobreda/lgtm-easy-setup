# lgtm-easy-setup

Script to deploy the LGTM stack (Loki, Grafana, Tempo, Mimir) using the grafana/otel-lgtm:latest image with persistent data storage

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

## License / Licença

MIT
