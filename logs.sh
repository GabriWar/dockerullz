#!/bin/bash

# HeavyStack Logs Viewer
# View logs from all services in your Docker stack

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored header
print_header() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to show usage
show_usage() {
    echo -e "${YELLOW}HeavyStack Logs Viewer${NC}"
    echo ""
    echo "Usage: ./logs.sh [OPTIONS] [SERVICE]"
    echo ""
    echo "OPTIONS:"
    echo "  -f, --follow           Follow log output (live tail)"
    echo "  -n, --lines N          Number of lines to show (default: 50)"
    echo "  -a, --all              Show all logs from all containers"
    echo "  -l, --list             List all running containers"
    echo "  -s, --search TERM      Search for a term in logs"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "SERVICES:"
    echo "  main                   Main stack services"
    echo "  media                  Media stack services (jellyfin, sonarr, etc.)"
    echo "  firecrawl              Firecrawl services"
    echo "  <container_name>       Specific container by name"
    echo ""
    echo "EXAMPLES:"
    echo "  ./logs.sh -a                    # Show all logs"
    echo "  ./logs.sh -f jellyfin           # Follow jellyfin logs"
    echo "  ./logs.sh -n 100 portainer      # Show last 100 lines of portainer"
    echo "  ./logs.sh -f main               # Follow all main stack logs"
    echo "  ./logs.sh -s \"error\" -n 200    # Search for 'error' in last 200 lines"
}

# Function to list all containers
list_containers() {
    print_header "📦 Running Containers"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -30
}

# Function to show logs from all containers
show_all_logs() {
    local lines=${1:-50}
    local follow=$2

    print_header "📋 All Container Logs (last $lines lines each)"

    for container in $(docker ps --format "{{.Names}}"); do
        echo -e "\n${MAGENTA}▶ $container${NC}"
        if [ "$follow" = "true" ]; then
            docker logs -f --tail=$lines $container 2>&1 &
        else
            docker logs --tail=$lines $container 2>&1 | sed 's/^/  /'
        fi
    done

    if [ "$follow" = "true" ]; then
        echo -e "\n${YELLOW}Following all logs... Press Ctrl+C to stop${NC}"
        wait
    fi
}

# Function to show logs from main stack
show_main_logs() {
    local lines=${1:-50}
    local follow=$2

    print_header "🔧 Main Stack Logs"

    if [ "$follow" = "true" ]; then
        docker compose logs -f --tail=$lines
    else
        docker compose logs --tail=$lines
    fi
}

# Function to show logs from media stack
show_media_logs() {
    local lines=${1:-50}
    local follow=$2

    print_header "🎬 Media Stack Logs"

    if [ "$follow" = "true" ]; then
        docker compose -f docker-compose.sudo.yml logs -f --tail=$lines
    else
        docker compose -f docker-compose.sudo.yml logs --tail=$lines
    fi
}

# Function to show logs from firecrawl
show_firecrawl_logs() {
    local lines=${1:-50}
    local follow=$2

    print_header "🕷️  Firecrawl Logs"

    cd firecrawl
    if [ "$follow" = "true" ]; then
        docker compose logs -f --tail=$lines
    else
        docker compose logs --tail=$lines
    fi
    cd ..
}

# Function to show logs from specific container
show_container_logs() {
    local container=$1
    local lines=${2:-50}
    local follow=$3

    # Check if container exists
    if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        echo -e "${RED}Error: Container '$container' not found${NC}"
        echo -e "\n${YELLOW}Available containers:${NC}"
        docker ps --format "  - {{.Names}}"
        exit 1
    fi

    print_header "📦 Logs for: $container"

    if [ "$follow" = "true" ]; then
        docker logs -f --tail=$lines --timestamps $container
    else
        docker logs --tail=$lines --timestamps $container
    fi
}

# Function to search logs
search_logs() {
    local search_term=$1
    local lines=${2:-100}

    print_header "🔍 Searching for: '$search_term'"

    for container in $(docker ps --format "{{.Names}}"); do
        local results=$(docker logs --tail=$lines $container 2>&1 | grep -i "$search_term")
        if [ ! -z "$results" ]; then
            echo -e "\n${MAGENTA}▶ $container${NC}"
            echo "$results" | sed 's/^/  /'
        fi
    done
}

# Parse arguments
FOLLOW=false
LINES=50
ACTION=""
SERVICE=""
SEARCH_TERM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -n|--lines)
            LINES="$2"
            shift 2
            ;;
        -a|--all)
            ACTION="all"
            shift
            ;;
        -l|--list)
            ACTION="list"
            shift
            ;;
        -s|--search)
            ACTION="search"
            SEARCH_TERM="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            SERVICE="$1"
            shift
            ;;
    esac
done

# Main logic
if [ "$ACTION" = "list" ]; then
    list_containers
elif [ "$ACTION" = "all" ]; then
    show_all_logs $LINES $FOLLOW
elif [ "$ACTION" = "search" ]; then
    search_logs "$SEARCH_TERM" $LINES
elif [ "$SERVICE" = "main" ]; then
    show_main_logs $LINES $FOLLOW
elif [ "$SERVICE" = "media" ]; then
    show_media_logs $LINES $FOLLOW
elif [ "$SERVICE" = "firecrawl" ]; then
    show_firecrawl_logs $LINES $FOLLOW
elif [ ! -z "$SERVICE" ]; then
    show_container_logs "$SERVICE" $LINES $FOLLOW
else
    show_usage
fi
