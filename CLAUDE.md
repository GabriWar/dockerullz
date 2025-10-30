# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HeavyStack is a comprehensive Docker-based infrastructure stack providing media management, automation, AI services, web scraping, backend services (Supabase), and system monitoring. It consists of 35+ containerized services organized into logical categories.

## Architecture

### Multi-Compose Setup

The project uses **four separate docker-compose setups** for different permission requirements and isolation:

1. **docker-compose.yml** - Main infrastructure services
   - Portainer, Vaultwarden, Nextcloud
   - AI services (Ollama, Open WebUI, Open Notebook)
   - Tools (Duplicati, Syncthing)
   - Bazarr, Lidarr (from media stack)

2. **docker-compose.sudo.yml** - Services requiring elevated permissions
   - Jellyfin (uses host network mode + GPU access)
   - Jellyseerr, Sonarr, Radarr, Prowlarr
   - qBittorrent, FlareSolverr
   - These services need special permissions for hardware access and file ownership

3. **firecrawl/docker-compose.yaml** - Web scraping services (isolated)
   - Firecrawl API, worker, playwright service
   - Built from source in separate directory
   - Uses .yaml extension (not .yml)

4. **supabase-project/docker-compose.yml** - Backend-as-a-Service stack
   - 13 services including Postgres, PostgREST, GoTrue (Auth), Storage
   - Self-hosted Supabase with custom port configuration
   - Isolated from main stack for security and resource management

### Startup Scripts

Four specialized startup scripts manage the stack:

- **start.sh** - Starts main infrastructure services
  - Exports MEDIA_PATH and DOWNLOADS_PATH environment variables
  - Creates necessary directories and Docker volumes
  - Starts docker-compose.yml services

- **start-sudo.sh** - Starts media stack with elevated permissions
  - Fixes config directory permissions (chown)
  - Creates external volumes (heavystack_myMedia, heavystack_myDlFolders)
  - Creates external network (heavystack_mediarr)
  - Starts docker-compose.sudo.yml with sudo

- **start-firecrawl.sh** - Builds and starts Firecrawl from source
  - Clones Firecrawl repository (if not present)
  - Builds Docker images from source (pre-built images are unstable)
  - Creates proper .env configuration
  - Handles docker-compose.yaml file (note: .yaml not .yml)

- **start-supabase.sh** - Starts self-hosted Supabase stack
  - Auto-generates JWT keys if needed (ANON_KEY, SERVICE_ROLE_KEY)
  - Pulls latest Supabase images
  - Starts 13 services in supabase-project/ directory
  - Displays access URLs and credentials

### Port Configuration

**Key port changes from defaults:**
- Vaultwarden: **8100** (not 8000, to avoid conflicts)
- Open WebUI: **3002** (not 3004)
- qBittorrent: **8080** (configurable, default was 8081)
- Open Notebook API: **5056** (external), 5055 (internal container port)
- Nextcloud HTTP: **8090** (not 80, to avoid conflicts)
- Nextcloud Admin: **8888**
- Nextcloud HTTPS: **8443**
- Jellyseerr: **5055**
- Firecrawl Postgres: **5433** (not 5432, local postgres conflict)
- Supabase Kong API: **8300** (not 8000, changed from 8200 due to Duplicati)
- Supabase Kong HTTPS: **8344** (not 8443, Nextcloud conflict)
- Supabase Postgres: **5434** (not 5432, local postgres + Firecrawl conflict)
- Supabase Pooler: **6543** (transaction pooling)

**Why these ports matter:**
- Open Notebook API_URL must point to external port 5056 (browser access)
- Multiple services had conflicts requiring remapping
- Supabase had three rounds of port adjustments (8000→8200→8300)
- PostgreSQL ports: local (5432), Firecrawl (5433), Supabase (5434)
- All ports are configurable via .env files

### Volume Architecture

**External Named Volumes (for media stack):**
- `heavystack_myMedia` - Bind mount to MEDIA_PATH
- `heavystack_myDlFolders` - Bind mount to DOWNLOADS_PATH
- These are created by start-sudo.sh and referenced as external in both compose files

**Internal Volumes:**
- `nextcloud_aio_mastercontainer` - Created explicitly by start.sh
- Service-specific volumes (portainer_data, vaultwarden_data, etc.)

### Network Architecture

**External Network:**
- `heavystack_mediarr` - Shared network for media services
- Created by start-sudo.sh
- Used by services in both compose files (Bazarr, Lidarr connect to it)

**Special Network Modes:**
- Jellyfin uses `network_mode: "host"` for GPU access and discovery
- Other services use bridge networking

## Common Operations

### Starting the Stack

**Full startup sequence:**
```bash
# 1. Start main infrastructure
./start.sh

# 2. Start media stack (requires sudo for permissions)
./start-sudo.sh

# 3. Start Supabase (Backend-as-a-Service)
./start-supabase.sh

# 4. Build and start Firecrawl (optional, takes several minutes)
# Note: Can be configured to use Supabase Postgres instead of own database
./start-firecrawl.sh
```

### Managing Services

**Main stack:**
```bash
docker compose ps                    # Check status
docker compose logs -f <service>     # View logs
docker compose restart <service>     # Restart service
docker compose down                  # Stop all (main)
```

**Media stack (sudo required):**
```bash
docker compose -f docker-compose.sudo.yml ps
docker compose -f docker-compose.sudo.yml logs -f jellyfin
sudo docker compose -f docker-compose.sudo.yml restart jellyseerr
```

**Firecrawl (in firecrawl/ subdirectory):**
```bash
cd firecrawl
docker compose ps
docker compose logs -f api
docker compose restart api
```

**Supabase (in supabase-project/ subdirectory):**
```bash
cd supabase-project
docker compose ps
docker compose logs -f studio        # Studio dashboard
docker compose logs -f kong          # API gateway
docker compose logs -f db            # Postgres database
docker compose logs -f supavisor     # Connection pooler
docker compose restart <service>
```

**Direct container management (when compose has issues):**
```bash
docker ps --filter "name=servicename"
docker restart servicename
docker logs servicename
docker stop servicename && docker rm servicename
```

### Environment Variable Updates

When environment variables change:

```bash
# For main stack - remove and recreate affected container
docker stop open-notebook && docker rm open-notebook
# Then use start.sh or docker run with new env vars

# For media stack - stop, remove, restart with sudo script
docker compose -f docker-compose.sudo.yml down
./start-sudo.sh

# Note: docker compose restart does NOT reload env vars
```

### Port Conflict Resolution

If adding/changing services:
1. Check .env.example for all configured ports
2. Update both .env and .env.example
3. Update dashboard.html with new port
4. Restart affected containers (not just compose restart)

## Critical Configuration Notes

### Open Notebook
- **API_URL must be external port (5056)** not internal (5055)
- Browser connects to external port, internal services use internal port
- Port mapping: `-p 5056:5055` means external:internal

### Nextcloud AIO
- Requires HTTPS for initial setup (https://localhost:8888)
- Self-signed certificate warnings are normal
- Don't use port 80 in production (conflicts, use 8090)
- Needs `/var/run/docker.sock` access to spawn additional containers

### Firecrawl
- Must be built from source (pre-built images fail)
- Uses docker-compose.yaml (not .yml)
- Script handles automatic rebuild detection
- Requires significant build time (5-10 minutes)

### Supabase
- **Port configuration is critical**: Uses 8300 (not 8000/8200) to avoid conflicts
- **VAULT_ENC_KEY must be exactly 32 bytes** for AES-256-GCM encryption
- **JWT keys auto-generated** by start-supabase.sh if not present
- **Default credentials**: User `heavystack`, password in supabase-project/.env
- Access Studio at http://localhost:8300 (protected with basic auth)
- Three database connection methods:
  - Pooled (transaction): port 6543 via Supavisor
  - Direct (session): port 5434
  - Internal: port 5432 (container-to-container only)
- Can be used as shared Postgres for other services (like Firecrawl)
- JWT_SECRET, ANON_KEY, and SERVICE_ROLE_KEY must stay synchronized

### Media Stack Permissions
- Jellyfin needs GPU access: `/dev/dri/renderD128`
- Config directories must be owned by correct PUID:PGID
- start-sudo.sh handles chown operations automatically
- External volumes required for cross-compose access

### Volume Caching Issue
If volumes show old paths after changing .env:
```bash
docker volume rm heavystack_myMedia heavystack_myDlFolders
./start-sudo.sh  # Recreates with correct paths
```

## Dashboard

**dashboard.html** - Vue.js single-file dashboard
- Update when adding services or changing ports
- Must match actual running configuration
- HTTPS URLs changed to HTTP to avoid browser warnings
- Organized by category: Infrastructure, AI, Web Scraping, Media, Tools

## Commented Out Services

Services intentionally disabled:
- **Netdata** - Commented out (network_mode: host conflicts)
- **n8n** - Commented out (had startup issues)
- **Readarr** - Commented out (architecture mismatch issues)
- **Firecrawl** - Commented out in main compose (use start-firecrawl.sh instead)

Do not uncomment these without addressing the underlying issues documented in git history.

## Important Patterns

### When adding new services:

1. Determine if it needs elevated permissions/GPU access
   - Yes: Add to docker-compose.sudo.yml
   - No: Add to docker-compose.yml

2. Configure port in .env and .env.example

3. If it needs media access, use external volumes:
   ```yaml
   volumes:
     - myMedia:/mnt/media
     - myDlFolders:/mnt/downloads
   ```

4. Add to dashboard.html in appropriate category

5. Document in README.md

### When troubleshooting port conflicts:

1. Check actual running ports: `docker ps --format "{{.Names}}: {{.Ports}}"`
2. Check .env for configured ports
3. Check if service uses internal port mapping
4. Verify no multiple services claim same port

### When dealing with permission issues:

1. Check PUID/PGID in .env matches file owner
2. Consider if service should be in docker-compose.sudo.yml
3. Use start-sudo.sh to auto-fix permissions
4. Remember: `docker compose restart` ≠ recreation with new permissions
