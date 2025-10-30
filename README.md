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
- **Open WebUI** (configurável) - Interface web para modelos de IA
- **Ollama** (11434) - Servidor local de modelos de IA
- **Firecrawl** (3003) - API de web scraping com Playwright

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
- **Syncthing** (8384) - Sincronização de arquivos P2P

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
- **Jellyfin**: http://localhost:8096 (usa network_mode: host)
- **Uptime Kuma**: http://localhost:3001
- **Nextcloud AIO**: http://localhost:8080
- **Open Notebook**: http://localhost:${OPEN_NOTEBOOK_PORT:-8502}
- **Open Notebook API**: http://localhost:${OPEN_NOTEBOOK_API_PORT:-5056}
- **Open WebUI**: http://localhost:${OPEN_WEBUI_PORT:-3004}
- **Ollama**: http://localhost:${OLLAMA_PORT:-11434}
- **Firecrawl API**: http://localhost:${FIRECRAWL_PORT:-3003}
- **Firecrawl Queue Manager**: http://localhost:${FIRECRAWL_PORT:-3003}/admin/${FIRECRAWL_BULL_AUTH_KEY:-CHANGEME}/queues
- **qBittorrent**: http://localhost:${QBITTORRENT_WEBUI_PORT:-8081}
- **Jellyseerr**: http://localhost:${JELLYSEERR_PORT:-5055}
- **Syncthing**: http://localhost:${SYNCTHING_WEB_PORT:-8384}
- **Duplicati**: http://localhost:8200

## ⚙️ Configuração

Edite o arquivo `.env` para personalizar:
- Timezone
- Caminhos de mídia
- Portas dos serviços
- Credenciais de banco de dados

### 🤖 Open WebUI + Ollama

Sistema completo de IA local com interface web moderna:

#### Open WebUI
- **Porta**: Configure `OPEN_WEBUI_PORT` no arquivo `.env` (padrão: 3002)
- **Modo single-user**: Ativado por padrão (sem necessidade de login)
- **Armazenamento persistente**: Dados salvos no volume `open_webui_data`
- **Conexão automática**: Conecta automaticamente ao Ollama local
- **Suporte a GPU**: Disponível (descomente as linhas no docker-compose.yml)

#### Ollama
- **Porta**: Configure `OLLAMA_PORT` no arquivo `.env` (padrão: 11434)
- **Armazenamento persistente**: Modelos salvos no volume `ollama_data`
- **Modelos disponíveis**: Baixe modelos via interface web ou CLI
- **Suporte a GPU**: Disponível (descomente as linhas no docker-compose.yml)

**Exemplo de configuração no .env:**
```bash
# Open WebUI
OPEN_WEBUI_PORT=3004
WEBUI_DOCKER_TAG=main-slim

# Ollama
OLLAMA_PORT=11434
OLLAMA_DOCKER_TAG=latest
```

**Como usar:**
1. Acesse `http://localhost:3004` (Open WebUI)
2. Baixe modelos de IA através da interface
3. Comece a conversar com os modelos localmente!

### 🕷️ Firecrawl + Playwright

Sistema completo de web scraping com suporte a JavaScript e automação:

#### Firecrawl API
- **Porta**: Configure `FIRECRAWL_PORT` no arquivo `.env` (padrão: 3003)
- **Playwright integrado**: Navegador headless completo para sites dinâmicos
- **Redis incluído**: Gerenciamento de filas e rate limiting
- **Queue Manager**: Interface web para monitorar scraping jobs
- **Sem autenticação**: Modo self-hosted simplificado por padrão

#### Recursos
- **Scraping**: Extrai conteúdo de páginas web (HTML, Markdown, JSON)
- **Crawling**: Navega recursivamente por sites
- **AI Features**: Extração estruturada com OpenAI (opcional)
- **Search API**: Integração com Google ou SearXNG
- **Playwright Service**: Renderização JavaScript completa
- **Proxy Support**: Suporte para proxies HTTP/HTTPS

**Exemplo de configuração no .env:**
```bash
# Firecrawl
FIRECRAWL_PORT=3003
FIRECRAWL_BULL_AUTH_KEY=sua_senha_segura
FIRECRAWL_OPENAI_API_KEY=sk-... # Opcional para AI features
FIRECRAWL_MAX_CPU=0.8 # Limite de CPU (80%)
FIRECRAWL_MAX_RAM=0.8 # Limite de RAM (80%)
```

**Como usar:**
1. Acesse a API em `http://localhost:3003`
2. Queue Manager: `http://localhost:3003/admin/CHANGEME/queues`
3. Teste o endpoint de scraping:
```bash
curl -X POST http://localhost:3003/v1/scrape \
    -H 'Content-Type: application/json' \
    -d '{"url": "https://example.com"}'
```

**Endpoints principais:**
- `POST /v1/scrape` - Scrape único de uma página
- `POST /v1/crawl` - Crawl recursivo de um site
- `POST /v1/search` - Busca na web
- `POST /v1/extract` - Extração estruturada com AI

**Integração com n8n:**
Firecrawl pode ser facilmente integrado com n8n para automações de web scraping!

### 🔄 Syncthing

Sistema descentralizado de sincronização de arquivos P2P:

#### Recursos
- **Sincronização P2P**: Sincronize arquivos diretamente entre dispositivos sem nuvem
- **Seguro**: Criptografia TLS e autenticação baseada em certificados
- **Privado**: Seus dados não passam por servidores de terceiros
- **Multiplataforma**: Funciona em Windows, Mac, Linux, Android, etc.
- **Versionamento**: Mantém versões antigas de arquivos
- **Open Source**: Software livre e auditável

**Exemplo de configuração no .env:**
```bash
# Syncthing
SYNCTHING_WEB_PORT=8384
SYNCTHING_LISTEN_PORT=22000
SYNCTHING_DISCOVERY_PORT=21027
SYNCTHING_DATA1=/mnt/syncthing/data1
SYNCTHING_DATA2=/mnt/syncthing/data2
```

**Como usar:**
1. Acesse a interface web: `http://localhost:8384`
2. **IMPORTANTE**: Configure usuário e senha em Actions -> Settings -> GUI
   - O Syncthing escuta em 0.0.0.0, então é crucial definir autenticação
3. Adicione pastas para sincronizar
4. Conecte com outros dispositivos usando Device IDs
5. Configure opções de sincronização (unidirecional, bidirecional, etc.)

**Portas utilizadas:**
- `8384`: Interface web (WebUI)
- `22000/tcp`: Porta de sincronização (TCP)
- `22000/udp`: Porta de sincronização (UDP)
- `21027/udp`: Descoberta de dispositivos locais

**Dica de segurança:**
Por padrão, o Syncthing não tem senha configurada. Sempre defina uma senha forte na primeira configuração!

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