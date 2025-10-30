#!/bin/bash

# HeavyStack Sudo Services Startup Script
# This script starts services that require special permissions (Jellyfin, Jellyseerr, and media stack)

echo "🔐 Starting HeavyStack services with elevated permissions..."
echo ""

# Export environment variables
export MEDIA_PATH=/home/gabriel/Desktop/mydockers/media
export DOWNLOADS_PATH=/home/gabriel/Desktop/mydockers/downloads

echo "📁 Media paths configured:"
echo "   MEDIA_PATH: $MEDIA_PATH"
echo "   DOWNLOADS_PATH: $DOWNLOADS_PATH"
echo ""

# Create directories if they don't exist
if [ ! -d "$MEDIA_PATH" ]; then
    echo "📂 Creating media directory..."
    mkdir -p "$MEDIA_PATH"
fi

if [ ! -d "$DOWNLOADS_PATH" ]; then
    echo "📂 Creating downloads directory..."
    mkdir -p "$DOWNLOADS_PATH"
fi

# Fix permissions on config directories
echo "🔧 Fixing config directory permissions..."

# Jellyfin config directories
if [ -d "./configs/jellyfin" ]; then
    echo "   Fixing Jellyfin permissions..."
    sudo chown -R ${JELLYFIN_PUID:-1000}:${JELLYFIN_PGID:-1000} ./configs/jellyfin
fi

# Jellyseerr config directory
if [ -d "./configs/mediarr/jellyseerr" ]; then
    echo "   Fixing Jellyseerr permissions..."
    sudo chown -R ${JELLYFIN_PUID:-1000}:${JELLYFIN_PGID:-1000} ./configs/mediarr/jellyseerr
fi

# Media stack config directories
for service in sonarr radarr prowlarr qbittorrent; do
    if [ -d "./configs/mediarr/$service" ]; then
        echo "   Fixing $service permissions..."
        sudo chown -R 1000:100 ./configs/mediarr/$service
    fi
done

echo ""

# Create Docker volumes if they don't exist
if ! docker volume ls | grep -q "heavystack_myMedia"; then
    echo "💾 Creating media volume..."
    docker volume create --driver local \
        --opt type=none \
        --opt device="$MEDIA_PATH" \
        --opt o=bind \
        heavystack_myMedia
fi

if ! docker volume ls | grep -q "heavystack_myDlFolders"; then
    echo "💾 Creating downloads volume..."
    docker volume create --driver local \
        --opt type=none \
        --opt device="$DOWNLOADS_PATH" \
        --opt o=bind \
        heavystack_myDlFolders
fi

# Create network if it doesn't exist
if ! docker network ls | grep -q "heavystack_mediarr"; then
    echo "🌐 Creating media network..."
    docker network create heavystack_mediarr
fi

echo ""
echo "🐳 Starting media stack services with Docker Compose..."
echo ""

# Start services with sudo
sudo docker compose -f docker-compose.sudo.yml up -d

# Check status
echo ""
echo "✅ Media stack startup complete!"
echo ""
echo "📊 Running media services:"
docker compose -f docker-compose.sudo.yml ps --format "table {{.Name}}\t{{.Status}}"

echo ""
echo "🌐 Access your services:"
echo "   Jellyfin: http://localhost:8096"
echo "   Jellyseerr: http://localhost:${JELLYSEERR_PORT:-5055}"
echo "   Sonarr: http://localhost:8989"
echo "   Radarr: http://localhost:7878"
echo "   Prowlarr: http://localhost:9696"
echo "   qBittorrent: http://localhost:${QBITTORRENT_WEBUI_PORT:-8081}"
echo ""
