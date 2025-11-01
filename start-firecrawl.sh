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
        echo "Skipping rebuild. Regenerating .env and starting existing containers..."
        cd "$FIRECRAWL_DIR"

        # Always regenerate .env to ensure it's up to date
        echo "⚙️  Regenerating Firecrawl configuration..."
        
        # Load Supabase configuration from supabase-project/.env if exists
        if [ -f ../supabase-project/.env ]; then
            echo "📋 Loading Supabase configuration..."
            source ../supabase-project/.env
            echo "✅ Supabase keys synchronized from supabase-project/.env"
        else
            echo "⚠️  Supabase .env not found, Supabase features may not work"
        fi
        
        # Regenerate .env file with updated variables
        # Automatically enable DB authentication if Supabase keys are available
        if [ -n "$ANON_KEY" ] && [ -n "$SERVICE_ROLE_KEY" ]; then
            ENABLE_DB_AUTH=${FIRECRAWL_USE_DB_AUTHENTICATION:-true}
        else
            ENABLE_DB_AUTH=${FIRECRAWL_USE_DB_AUTHENTICATION:-false}
        fi
        
        cat > .env <<EOF
# Port Configuration (external port, internal is 3002)
PORT=${FIRECRAWL_PORT:-3003}
INTERNAL_PORT=3002
HOST=0.0.0.0

# Redis Configuration
REDIS_URL=redis://redis:6379
REDIS_RATE_LIMIT_URL=redis://redis:6379

# Playwright Service
PLAYWRIGHT_MICROSERVICE_URL=http://playwright-service:3000/scrape

# Database Configuration - Using Supabase for authentication
# Note: Change tracking requires Supabase, so set to true if you want to use change tracking
# Even with USE_DB_AUTHENTICATION=true, API keys are still optional for self-hosted instances
USE_DB_AUTHENTICATION=$ENABLE_DB_AUTH

# Supabase Configuration
# For Docker network, use host.docker.internal to access Supabase on host machine
# Supabase Kong is running on port 8300 on the host machine (from mydockers)
SUPABASE_URL=http://host.docker.internal:8300
SUPABASE_REPLICA_URL=http://host.docker.internal:8300
SUPABASE_ANON_TOKEN=${ANON_KEY:-}
SUPABASE_SERVICE_TOKEN=${SERVICE_ROLE_KEY:-}

# Firecrawl API Key (for self-hosted authentication bypass)
TEST_API_KEY=${FIRECRAWL_TEST_API_KEY:-CHANGEME}

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
SEARXNG_ENGINES=${FIRECRAWL_SEARXNG_ENGINES:-}
SEARXNG_CATEGORIES=${FIRECRAWL_SEARXNG_CATEGORIES:-}

# Optional: Search API keys
SERPER_API_KEY=${FIRECRAWL_SERPER_API_KEY:-}
SEARCHAPI_API_KEY=${FIRECRAWL_SEARCHAPI_API_KEY:-}

# Optional: AI features (beyond OpenAI)
MODEL_NAME=${FIRECRAWL_MODEL_NAME:-}
MODEL_EMBEDDING_NAME=${FIRECRAWL_MODEL_EMBEDDING_NAME:-}
OLLAMA_BASE_URL=${FIRECRAWL_OLLAMA_BASE_URL:-}

# Optional: Monitoring and logging
POSTHOG_API_KEY=${FIRECRAWL_POSTHOG_API_KEY:-}
POSTHOG_HOST=${FIRECRAWL_POSTHOG_HOST:-}
LOGGING_LEVEL=${FIRECRAWL_LOGGING_LEVEL:-}
SELF_HOSTED_WEBHOOK_URL=${FIRECRAWL_SELF_HOSTED_WEBHOOK_URL:-}

# Optional: Playwright settings
BLOCK_MEDIA=${FIRECRAWL_BLOCK_MEDIA:-}

# System Resource Limits
MAX_CPU=${FIRECRAWL_MAX_CPU:-0.8}
MAX_RAM=${FIRECRAWL_MAX_RAM:-0.8}
EOF
        
        echo "✅ Configuration file regenerated"
        echo ""

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

# Load Supabase configuration from supabase-project/.env if exists
# This ensures Firecrawl always uses the latest Supabase credentials
if [ -f ../supabase-project/.env ]; then
    echo "📋 Loading Supabase configuration..."
    source ../supabase-project/.env
    echo "✅ Supabase keys synchronized from supabase-project/.env"
    
    # Verify keys are available
    if [ -z "$ANON_KEY" ] || [ -z "$SERVICE_ROLE_KEY" ]; then
        echo "⚠️  Warning: Supabase keys (ANON_KEY or SERVICE_ROLE_KEY) not found in supabase-project/.env"
        echo "   Run ./start-supabase.sh first to generate the keys"
    fi
else
    echo "⚠️  Supabase .env not found, Supabase features may not work"
    echo "   Run ./start-supabase.sh first to initialize Supabase"
fi

# Create or update .env file with our custom configuration
# Automatically enable DB authentication if Supabase keys are available
if [ -n "$ANON_KEY" ] && [ -n "$SERVICE_ROLE_KEY" ]; then
    ENABLE_DB_AUTH=${FIRECRAWL_USE_DB_AUTHENTICATION:-true}
else
    ENABLE_DB_AUTH=${FIRECRAWL_USE_DB_AUTHENTICATION:-false}
fi

cat > .env <<EOF
# Port Configuration (external port, internal is 3002)
PORT=${FIRECRAWL_PORT:-3003}
INTERNAL_PORT=3002
HOST=0.0.0.0

# Redis Configuration
REDIS_URL=redis://redis:6379
REDIS_RATE_LIMIT_URL=redis://redis:6379

# Playwright Service
PLAYWRIGHT_MICROSERVICE_URL=http://playwright-service:3000/scrape

# Database Configuration - Using Supabase for authentication
# Note: Change tracking requires Supabase, so set to true if you want to use change tracking
# Even with USE_DB_AUTHENTICATION=true, API keys are still optional for self-hosted instances
USE_DB_AUTHENTICATION=$ENABLE_DB_AUTH

# Supabase Configuration
# For Docker network, use host.docker.internal to access Supabase on host machine
# Supabase Kong is running on port 8300 on the host machine (from mydockers)
SUPABASE_URL=http://host.docker.internal:8300
SUPABASE_REPLICA_URL=http://host.docker.internal:8300
SUPABASE_ANON_TOKEN=${ANON_KEY:-}
SUPABASE_SERVICE_TOKEN=${SERVICE_ROLE_KEY:-}

# Firecrawl API Key (for self-hosted authentication bypass)
TEST_API_KEY=${FIRECRAWL_TEST_API_KEY:-CHANGEME}

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
SEARXNG_ENGINES=${FIRECRAWL_SEARXNG_ENGINES:-}
SEARXNG_CATEGORIES=${FIRECRAWL_SEARXNG_CATEGORIES:-}

# Optional: Search API keys
SERPER_API_KEY=${FIRECRAWL_SERPER_API_KEY:-}
SEARCHAPI_API_KEY=${FIRECRAWL_SEARCHAPI_API_KEY:-}

# Optional: AI features (beyond OpenAI)
MODEL_NAME=${FIRECRAWL_MODEL_NAME:-}
MODEL_EMBEDDING_NAME=${FIRECRAWL_MODEL_EMBEDDING_NAME:-}
OLLAMA_BASE_URL=${FIRECRAWL_OLLAMA_BASE_URL:-}

# Optional: Monitoring and logging
POSTHOG_API_KEY=${FIRECRAWL_POSTHOG_API_KEY:-}
POSTHOG_HOST=${FIRECRAWL_POSTHOG_HOST:-}
LOGGING_LEVEL=${FIRECRAWL_LOGGING_LEVEL:-}
SELF_HOSTED_WEBHOOK_URL=${FIRECRAWL_SELF_HOSTED_WEBHOOK_URL:-}

# Optional: Playwright settings
BLOCK_MEDIA=${FIRECRAWL_BLOCK_MEDIA:-}

# System Resource Limits
MAX_CPU=${FIRECRAWL_MAX_CPU:-0.8}
MAX_RAM=${FIRECRAWL_MAX_RAM:-0.8}
EOF

echo "✅ Configuration file created"
echo ""

# Create blocklist table in Supabase if it doesn't exist
echo "📊 Verifying Supabase blocklist table..."
if [ -f ../supabase-project/.env ]; then
    source ../supabase-project/.env
    if [ -n "$POSTGRES_PASSWORD" ]; then
        # Check if supabase-db container is running
        if docker ps --filter "name=supabase-db" --format "{{.Names}}" | grep -q "^supabase-db$"; then
            # Create blocklist table if it doesn't exist
            docker exec supabase-db psql -U postgres -d postgres -c "
            CREATE TABLE IF NOT EXISTS public.blocklist (
                id SERIAL PRIMARY KEY,
                data JSONB NOT NULL DEFAULT '{\"blocklist\": [], \"allowedKeywords\": []}'::jsonb,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );" 2>&1 | grep -v "CREATE TABLE" || echo "   Tabela blocklist verificada/criada"
            
            # Insert initial row if table is empty (check if table has any rows first)
            ROW_COUNT=$(docker exec supabase-db psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM public.blocklist;" 2>&1 | tr -d ' ' | head -1)
            if [ "$ROW_COUNT" = "0" ]; then
                docker exec supabase-db psql -U postgres -d postgres -c "
                INSERT INTO public.blocklist (data)
                VALUES ('{\"blocklist\": [], \"allowedKeywords\": []}'::jsonb);" 2>&1 | grep -v "INSERT" && echo "   Registro inicial criado"
            else
                echo "   Registro inicial já existe ($ROW_COUNT registro(s))"
            fi
            
            echo "✅ Blocklist table ready"
            
            # Create Firecrawl authentication schema if it doesn't exist
            echo "📊 Creating Firecrawl authentication schema..."
            if [ -f ../firecrawl-auth-schema.sql ]; then
                # Copy SQL file into container
                docker cp ../firecrawl-auth-schema.sql supabase-db:/tmp/firecrawl-auth-schema.sql
                docker exec supabase-db psql -U postgres -d postgres -f /tmp/firecrawl-auth-schema.sql > /dev/null 2>&1 && echo "   ✅ Firecrawl auth schema created"
            else
                echo "   ⚠️  firecrawl-auth-schema.sql not found, skipping auth schema creation"
            fi
        else
            echo "⚠️  Supabase database container not running, skipping blocklist table creation"
        fi
    else
        echo "⚠️  Supabase POSTGRES_PASSWORD not found, skipping blocklist table creation"
    fi
else
    echo "⚠️  Supabase .env not found, skipping blocklist table creation"
fi
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
