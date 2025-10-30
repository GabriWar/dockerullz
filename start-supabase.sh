#!/bin/bash

# HeavyStack - Supabase Startup Script
# Self-hosted Supabase with custom port configuration

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🚀 HeavyStack - Supabase Startup${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Docker is not running${NC}"
    exit 1
fi

# Navigate to supabase-project directory
cd supabase-project

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ Error: .env file not found in supabase-project/${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Checking configuration...${NC}"

# Check if ANON_KEY and SERVICE_ROLE_KEY need to be generated
if grep -q "ANON_KEY=WILL_BE_GENERATED" .env || grep -q "SERVICE_ROLE_KEY=WILL_BE_GENERATED" .env; then
    echo -e "${YELLOW}🔑 Generating JWT keys...${NC}"

    # Get JWT_SECRET from .env
    JWT_SECRET=$(grep "^JWT_SECRET=" .env | cut -d'=' -f2)

    # Function to create JWT
    create_jwt() {
        local role=$1
        local iat=$(date +%s)
        local exp=$((iat + 315360000))  # 10 years

        # Header and payload
        header='{"alg":"HS256","typ":"JWT"}'
        payload="{\"role\":\"$role\",\"iss\":\"supabase\",\"iat\":$iat,\"exp\":$exp}"

        # Encode
        header_b64=$(echo -n "$header" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
        payload_b64=$(echo -n "$payload" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

        # Sign
        signature=$(echo -n "${header_b64}.${payload_b64}" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

        echo "${header_b64}.${payload_b64}.${signature}"
    }

    # Generate keys
    ANON_KEY=$(create_jwt "anon")
    SERVICE_ROLE_KEY=$(create_jwt "service_role")

    # Update .env file
    sed -i "s|ANON_KEY=.*|ANON_KEY=$ANON_KEY|" .env
    sed -i "s|SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY|" .env

    echo -e "${GREEN}✓ JWT keys generated${NC}"
fi

# Pull latest images
echo -e "${YELLOW}📥 Pulling latest Supabase images (this may take a few minutes)...${NC}"
docker compose pull

# Start services
echo -e "${GREEN}🔧 Starting Supabase services...${NC}"
docker compose up -d

# Wait a moment for services to initialize
sleep 3

# Check service status
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📦 Supabase Services Status:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

docker compose ps

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Supabase Started Successfully!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}📍 Access Points:${NC}"
echo -e "  ${CYAN}Studio Dashboard:${NC} http://localhost:8300"
echo -e "  ${CYAN}API Gateway:${NC}      http://localhost:8300"
echo -e "  ${CYAN}Database (pooled):${NC} postgresql://postgres.heavystack-tenant:<password>@localhost:6543/postgres"
echo -e "  ${CYAN}Database (direct):${NC} postgresql://postgres:<password>@localhost:5434/postgres"
echo ""
echo -e "${YELLOW}🔐 Credentials:${NC}"
echo -e "  ${CYAN}Dashboard User:${NC}     heavystack"
echo -e "  ${CYAN}Dashboard Pass:${NC}     (check .env file)"
echo -e "  ${CYAN}DB Password:${NC}        (check .env file)"
echo ""
echo -e "${YELLOW}📚 API Endpoints:${NC}"
echo -e "  ${CYAN}REST:${NC}     http://localhost:8300/rest/v1/"
echo -e "  ${CYAN}Auth:${NC}     http://localhost:8300/auth/v1/"
echo -e "  ${CYAN}Storage:${NC}  http://localhost:8300/storage/v1/"
echo -e "  ${CYAN}Realtime:${NC} http://localhost:8300/realtime/v1/"
echo ""
echo -e "${GREEN}💡 Tips:${NC}"
echo -e "  - View logs: ${CYAN}./logs.sh supabase-studio${NC} (or any service name)"
echo -e "  - Stop services: ${CYAN}cd supabase-project && docker compose down${NC}"
echo -e "  - Restart: ${CYAN}./start-supabase.sh${NC}"
echo ""
