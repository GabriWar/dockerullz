#!/bin/bash

# HeavyStack Startup Script
# This script exports required environment variables and starts all Docker services

echo "🚀 Starting HeavyStack..."
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

# Create Nextcloud volume if it doesn't exist
if ! docker volume ls | grep -q "nextcloud_aio_mastercontainer"; then
    echo "💾 Creating Nextcloud AIO volume..."
    docker volume create nextcloud_aio_mastercontainer
fi

echo ""
echo "🐳 Starting Docker Compose services..."
echo ""

# Start all services
docker compose up -d

# Check status
echo ""
echo "✅ Startup complete!"
echo ""
echo "📊 Running services:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -v buildx | head -20

echo ""
echo "Total services running: $(docker ps --format "{{.Names}}" | grep -v buildx | wc -l)"
echo ""
echo "📝 Note: Media stack services (Jellyfin, Jellyseerr, Sonarr, Radarr, etc.)"
echo "   require elevated permissions. Start them with:"
echo "   ./start-sudo.sh"
echo ""
echo "🌐 Open dashboard.html in your browser to see all service URLs!"
echo ""
