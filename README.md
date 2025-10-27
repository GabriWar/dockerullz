# HeavyStack 🚀

Um stack completo de containers Docker para automação, mídia e monitoramento.

## 📋 Serviços Incluídos

### 🔧 Infraestrutura
- **Portainer** (9000) - Gerenciamento de containers
- **Vaultwarden** (8000) - Gerenciador de senhas
- **Netdata** (19999) - Monitoramento de sistema
- **n8n** (5678) - Automação de workflows
- **Homepage** (3000) - Dashboard centralizado
- **Uptime Kuma** (3001) - Monitoramento de uptime
- **Nextcloud AIO** (80/8080/8443) - Nuvem privada completa
- **Open Notebook** (8502/5055) - Notebook AI com OpenAI

### 🎬 Stack de Mídia
- **Jellyfin** (8096) - Servidor de mídia
- **Jellyseerr** (5055) - Interface de requisições
- **Bazarr** (6767) - Gerenciador de legendas
- **Prowlarr** (9696) - Indexador de torrents
- **FlareSolverr** - Resolvedor de CAPTCHAs
- **qBittorrent** (8080) - Cliente de torrents
- **Radarr** (7878) - Gerenciador de filmes
- **Readarr** (8787) - Gerenciador de livros
- **Sonarr** (8989) - Gerenciador de séries
- **Lidarr** (8686) - Gerenciador de música

### 🛠️ Ferramentas
- **Duplicati** (8200) - Backup automatizado

## 🚀 Instalação

1. Clone o repositório:
```bash
git clone https://github.com/GabriWar/dockerullz.git
cd dockerullz
```

2. Configure as variáveis de ambiente:
```bash
cp .env.example .env
nano .env
```

3. Crie os diretórios necessários:
```bash
sudo mkdir -p /mnt/media /mnt/HDD/downloads
sudo mkdir -p ./configs/{jellyfin,homepage,duplicati,mediarr}
```

4. Execute o stack:
```bash
docker-compose up -d
```

## 🌐 Acesso

- **Homepage**: http://localhost:3000
- **Portainer**: http://localhost:9000
- **Jellyfin**: http://localhost:8096
- **Uptime Kuma**: http://localhost:3001
- **Nextcloud AIO**: http://localhost:8080
- **Open Notebook**: http://localhost:8502

## ⚙️ Configuração

Edite o arquivo `.env` para personalizar:
- Timezone
- Caminhos de mídia
- Portas dos serviços
- Credenciais de banco de dados

## 📁 Estrutura

```
.
├── docker-compose.yml
├── .env
├── .env.example
├── README.md
└── configs/
    ├── jellyfin/
    ├── homepage/
    ├── duplicati/
    └── mediarr/
```

## 🔧 Requisitos

- Docker
- Docker Compose
- 4GB+ RAM recomendado
- Espaço em disco para mídia

## 📝 Licença

MIT