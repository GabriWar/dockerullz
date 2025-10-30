#!/bin/bash

# Firecrawl Setup and Startup Script
# This script clones Firecrawl from source and builds it with Docker Compose

echo "🕷️  Firecrawl Setup Script"
echo ""

# Load environment variables from main .env
if [ -f .env ]; then
    echo "📋 Loading configuration from main .env..."
    source .env
else
    echo "⚠️  Warning: Main .env file not found, using defaults"
fi

FIRECRAWL_DIR="./firecrawl"

# Check if Firecrawl directory already exists
if [ -d "$FIRECRAWL_DIR" ]; then
    echo "📁 Firecrawl directory already exists"
    read -p "Do you want to rebuild? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping rebuild. Starting existing containers..."
        cd "$FIRECRAWL_DIR"

        # Use the correct compose file
        COMPOSE_FILE="docker-compose.yml"
        if [ -f "docker-compose.yaml" ]; then
            COMPOSE_FILE="docker-compose.yaml"
        fi

        docker compose -f "$COMPOSE_FILE" up -d
        cd ..
        exit 0
    fi
    echo "🔄 Updating Firecrawl repository..."
    cd "$FIRECRAWL_DIR"
    git pull
    cd ..
else
    echo "📥 Cloning Firecrawl repository..."
    git clone https://github.com/mendableai/firecrawl.git "$FIRECRAWL_DIR"
fi

# Navigate to Firecrawl directory
cd "$FIRECRAWL_DIR"

echo ""
echo "⚙️  Configuring Firecrawl..."

# Create or update .env file with our custom configuration
cat > .env <<EOF
# Port Configuration
PORT=${FIRECRAWL_PORT:-3003}

# Redis Configuration
REDIS_URL=redis://redis:6379
REDIS_RATE_LIMIT_URL=redis://redis:6379

# Playwright Service
PLAYWRIGHT_MICROSERVICE_URL=http://playwright-service:3000/scrape

# Database Configuration (if using PostgreSQL for auth)
USE_DB_AUTHENTICATION=${FIRECRAWL_USE_DB_AUTHENTICATION:-false}

# Bull Queue Authentication
BULL_AUTH_KEY=${FIRECRAWL_BULL_AUTH_KEY:-CHANGEME}

# Optional: OpenAI API Key for AI features
OPENAI_API_KEY=${FIRECRAWL_OPENAI_API_KEY:-}

# Optional: Proxy settings
PROXY_SERVER=${FIRECRAWL_PROXY_SERVER:-}
PROXY_USERNAME=${FIRECRAWL_PROXY_USERNAME:-}
PROXY_PASSWORD=${FIRECRAWL_PROXY_PASSWORD:-}

# Optional: SearXNG endpoint for search API
SEARXNG_ENDPOINT=${FIRECRAWL_SEARXNG_ENDPOINT:-}

# System Resource Limits
MAX_CPU=${FIRECRAWL_MAX_CPU:-0.8}
MAX_RAM=${FIRECRAWL_MAX_RAM:-0.8}
EOF

echo "✅ Configuration file created"
echo ""

# Check if docker-compose file exists (either .yml or .yaml)
if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ]; then
    echo "❌ Error: docker-compose file not found in Firecrawl directory"
    echo "   The repository structure may have changed."
    echo "   Please check: https://github.com/mendableai/firecrawl"
    cd ..
    exit 1
fi

# Use the correct compose file
COMPOSE_FILE="docker-compose.yml"
if [ -f "docker-compose.yaml" ]; then
    COMPOSE_FILE="docker-compose.yaml"
fi

echo "🔨 Building Firecrawl images (this may take a few minutes)..."
echo ""

# Build the images
docker compose -f "$COMPOSE_FILE" build

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Build failed. Please check the error messages above."
    cd ..
    exit 1
fi

echo ""
echo "✅ Build complete!"
echo ""
echo "🐳 Starting Firecrawl services..."
echo ""

# Start the services
docker compose -f "$COMPOSE_FILE" up -d

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Failed to start services. Please check the error messages above."
    cd ..
    exit 1
fi

# Check status
echo ""
echo "✅ Firecrawl startup complete!"
echo ""
echo "📊 Running Firecrawl services:"
docker compose -f "$COMPOSE_FILE" ps

echo ""
echo "🌐 Access Firecrawl API at: http://localhost:${FIRECRAWL_PORT:-3003}"
echo ""
echo "📖 API Documentation: https://docs.firecrawl.dev"
echo ""
echo "💡 Tip: Check logs with: cd firecrawl && docker compose logs -f"
echo ""

# Return to main directory
cd ..
