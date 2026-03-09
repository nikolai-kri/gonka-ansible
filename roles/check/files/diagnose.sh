#!/bin/bash

# Gonka services diagnostics script
# Usage: ./diagnose.sh [--verbose] [--logs]

set -e

VERBOSE=false
SHOW_LOGS=false
API_PORT=8000
ADMIN_PORT=9200
MLNODE_PORT=8080
CHAIN_RPC_PORT=26657

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --logs|-l)
            SHOW_LOGS=true
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 [--verbose] [--logs]"
            exit 1
            ;;
    esac
done

# Output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print section header
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Print status line
print_status() {
    if [ "$1" = "OK" ]; then
        echo -e "${GREEN}✓${NC} $2"
    elif [ "$1" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Load environment variables
if [ -f config.env ]; then
    source config.env
    print_status "OK" "Loaded config.env"
else
    print_status "WARN" "config.env not found, using defaults"
fi

# Ports from config.env or defaults
API_PORT=${API_PORT:-8000}
ADMIN_PORT=${DAPI_API__ADMIN_SERVER_PORT:-9200}
MLNODE_PORT=${PORT:-8080}
CHAIN_RPC_PORT=26657

# Check dependencies
print_header "Dependency check"

if ! command -v docker &> /dev/null; then
    print_status "FAIL" "docker not found"
    exit 1
fi
print_status "OK" "docker found"

if ! command -v curl &> /dev/null; then
    print_status "FAIL" "curl not found"
    exit 1
fi
print_status "OK" "curl found"

if ! command -v jq &> /dev/null; then
    print_status "WARN" "jq not found (some features will be limited)"
    HAS_JQ=false
else
    print_status "OK" "jq found"
    HAS_JQ=true
fi

print_header "Gonka services diagnostics"
echo "Time: $(date)"
echo "Working directory: $(pwd)"

# 1. Docker containers status
print_header "1. Docker containers status"

EXPECTED_CONTAINERS=("tmkms" "node" "api" "proxy" "mlnode-308" "inference")
COMPOSE_CMD="docker compose -f docker-compose.yml -f docker-compose.mlnode.yml"

if [ -n "$($COMPOSE_CMD ps -q 2>/dev/null)" ]; then
    print_status "OK" "Docker Compose is running"
    
    echo -e "\nContainer list:"
    $COMPOSE_CMD ps
    
    echo -e "\nContainer status:"
    for container in "${EXPECTED_CONTAINERS[@]}"; do
        # Find container by exact name or partial match (for docker compose with project prefix)
        found_container=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E "^${container}$|${container}" | head -1)
        
        if [ -n "$found_container" ]; then
            status=$(docker inspect --format='{{.State.Status}}' "$found_container" 2>/dev/null || echo "not found")
            health=$(docker inspect --format='{{.State.Health.Status}}' "$found_container" 2>/dev/null || echo "no healthcheck")
            if [ "$status" = "running" ]; then
                if [ "$health" = "healthy" ] || [ "$health" = "no healthcheck" ]; then
                    if [ "$found_container" = "$container" ]; then
                        print_status "OK" "Container $container: $status"
                    else
                        print_status "OK" "Container $container (found as $found_container): $status"
                    fi
                else
                    print_status "WARN" "Container $container ($found_container): $status (health: $health)"
                fi
            else
                print_status "FAIL" "Container $container ($found_container): $status"
            fi
        else
            # Check via docker compose ps (by partial name)
            if $COMPOSE_CMD ps --format json 2>/dev/null | grep -q "${container}"; then
                print_status "WARN" "Container $container found in compose but not running"
            else
                print_status "WARN" "Container $container not found"
            fi
        fi
    done
else
    print_status "FAIL" "Docker Compose not running or containers not found"
    echo "Try starting:"
    echo "  source config.env && docker compose -f docker-compose.yml -f docker-compose.mlnode.yml up -d"
fi

# 2. Check logs for errors
print_header "2. Check logs for errors"

if [ "$SHOW_LOGS" = true ]; then
    for container in "${EXPECTED_CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo -e "\nRecent errors in container $container:"
            docker logs "$container" --tail 50 2>&1 | grep -i "error\|fatal\|panic\|failed" | tail -5 || echo "  No errors found"
        fi
    done
else
    echo "Use --logs to view errors in logs"
fi

# 3. Check API endpoints availability
print_header "3. API endpoints availability"

# 3.1 Chain RPC
echo -n "Checking Chain RPC (localhost:${CHAIN_RPC_PORT}/status)... "
if curl -s -f "http://localhost:${CHAIN_RPC_PORT}/status" > /dev/null 2>&1; then
    print_status "OK" "Chain RPC available"
    if [ "$VERBOSE" = true ]; then
        if [ "$HAS_JQ" = true ]; then
            chain_status=$(curl -s "http://localhost:${CHAIN_RPC_PORT}/status" | jq -r '.result.sync_info.latest_block_height // "unknown"' 2>/dev/null || echo "unknown")
            echo "  Block height: $chain_status"
        else
            echo "  (jq not installed, detailed info unavailable)"
        fi
    fi
else
    print_status "FAIL" "Chain RPC unavailable"
fi

# 3.2 API Health
echo -n "Checking API Health (localhost:${API_PORT}/health)... "
if curl -s -f "http://localhost:${API_PORT}/health" > /dev/null 2>&1; then
    print_status "OK" "API Health endpoint available"
else
    print_status "FAIL" "API Health endpoint unavailable"
fi

# 3.3 Admin API
echo -n "Checking Admin API (localhost:${ADMIN_PORT}/admin/v1/nodes)... "
admin_response=$(curl -s -w "\n%{http_code}" "http://localhost:${ADMIN_PORT}/admin/v1/nodes" 2>/dev/null || echo -e "\n000")
http_code=$(echo "$admin_response" | tail -1)
if [ "$http_code" = "200" ]; then
    print_status "OK" "Admin API available"
    if [ "$VERBOSE" = true ] && [ "$HAS_JQ" = true ]; then
        nodes=$(echo "$admin_response" | head -n -1 | jq -r 'length // 0' 2>/dev/null || echo "0")
        echo "  Registered nodes: $nodes"
    fi
else
    print_status "FAIL" "Admin API unavailable (HTTP $http_code)"
fi

# 3.4 MLNode API
echo -n "Checking MLNode API (localhost:${MLNODE_PORT})... "
MLNODE_API_OK=false
for endpoint in "/docs" "/health" "/api/v1/health" "/api/v1/inference/up/status" ""; do
    if curl -s -f --max-time 3 "http://localhost:${MLNODE_PORT}${endpoint}" > /dev/null 2>&1; then
        MLNODE_API_OK=true
        break
    fi
done

if [ "$MLNODE_API_OK" = true ]; then
    print_status "OK" "MLNode API available"
else
    print_status "FAIL" "MLNode API unavailable"
fi

# 4. Check vLLM status via MLNode API
print_header "4. vLLM status check"

if curl -s -f "http://localhost:${MLNODE_PORT}/api/v1/inference/up/status" > /dev/null 2>&1; then
    vllm_status=$(curl -s "http://localhost:${MLNODE_PORT}/api/v1/inference/up/status" 2>/dev/null || echo "{}")
    if [ "$HAS_JQ" = true ] && echo "$vllm_status" | jq -e '.status' > /dev/null 2>&1; then
        status=$(echo "$vllm_status" | jq -r '.status // "unknown"')
        if [ "$status" = "running" ] || [ "$status" = "ready" ]; then
            print_status "OK" "vLLM status: $status"
        else
            print_status "WARN" "vLLM status: $status"
        fi
        if [ "$VERBOSE" = true ]; then
            echo "$vllm_status" | jq '.'
        fi
    elif [ "$HAS_JQ" = false ]; then
        # Without jq just show raw response
        if echo "$vllm_status" | grep -q "running\|ready"; then
            print_status "OK" "vLLM is running (details unavailable without jq)"
        else
            print_status "WARN" "vLLM status unclear (install jq for details)"
        fi
        if [ "$VERBOSE" = true ]; then
            echo "$vllm_status"
        fi
    else
        print_status "WARN" "Could not get vLLM status"
    fi
else
    print_status "FAIL" "Could not connect to MLNode API to check vLLM"
fi

# 5. Check node status via Admin API
print_header "5. Node status check"

if [ "$http_code" = "200" ]; then
    nodes_json=$(echo "$admin_response" | head -n -1)
    if [ "$HAS_JQ" = true ]; then
        if echo "$nodes_json" | jq -e '.nodes' > /dev/null 2>&1; then
            nodes_json=$(echo "$nodes_json" | jq '.nodes')
        fi
        
        node_count=$(echo "$nodes_json" | jq -r 'length // 0' 2>/dev/null || echo "0")
        if [ "$node_count" -gt 0 ]; then
            print_status "OK" "Nodes found: $node_count"
            echo ""
            echo "$nodes_json" | jq -r '.[] | "  ID: \(.id // .Id // "unknown"), Enabled: \(.state.admin_state.enabled // .State.AdminState.Enabled // "unknown"), Status: \(.state.status // .State.Status // "unknown")"' 2>/dev/null || \
            echo "$nodes_json" | jq -r '.[] | "  ID: \(.id), Enabled: \(.state.admin_state.enabled), Status: \(.state.status)"' 2>/dev/null || \
            echo "  Could not parse node information"
            
            if [ "$VERBOSE" = true ]; then
                echo ""
                echo "Full node information:"
                echo "$nodes_json" | jq '.'
            fi
        else
            print_status "WARN" "No nodes found or registered"
        fi
    else
        print_status "OK" "Admin API responds (install jq for details)"
        if [ "$VERBOSE" = true ]; then
            echo "$nodes_json"
        fi
    fi
else
    print_status "FAIL" "Could not get node list"
fi

# 6. Network connectivity check
print_header "6. Network connectivity check"

if [ -n "$SEED_NODE_RPC_URL" ]; then
    seed_host=$(echo "$SEED_NODE_RPC_URL" | sed 's|http://||' | cut -d: -f1)
    echo -n "Checking connection to seed node ($seed_host)... "
    if curl -s -f --max-time 5 "$SEED_NODE_RPC_URL/status" > /dev/null 2>&1; then
        print_status "OK" "Connection to seed node works"
    else
        print_status "WARN" "Could not connect to seed node"
    fi
fi

# 7. GPU check (if available)
print_header "7. GPU check"

if command -v nvidia-smi &> /dev/null; then
    gpu_count=$(nvidia-smi --list-gpus | wc -l)
    if [ "$gpu_count" -gt 0 ]; then
        print_status "OK" "GPUs found: $gpu_count"
        if [ "$VERBOSE" = true ]; then
            echo ""
            nvidia-smi --query-gpu=index,name,memory.total,memory.used,utilization.gpu --format=csv,noheader,nounits | \
            while IFS=',' read -r index name mem_total mem_used util; do
                echo "  GPU $index: $name, Memory: ${mem_used}MB/${mem_total}MB, Utilization: ${util}%"
            done
        fi
    else
        print_status "WARN" "No GPUs found"
    fi
else
    print_status "WARN" "nvidia-smi not found (GPU check skipped)"
fi

# 8. Disk space check
print_header "8. Disk space check"

if [ -n "$HF_HOME" ]; then
    hf_path="$HF_HOME"
else
    hf_path="${HOME}/.cache/huggingface"
fi

if [ -d "$hf_path" ]; then
    hf_size=$(du -sh "$hf_path" 2>/dev/null | cut -f1 || echo "unknown")
    print_status "OK" "HF cache: $hf_size ($hf_path)"
else
    print_status "WARN" "HF cache not found: $hf_path"
fi

# Summary
print_header "Summary"

echo "For more details use:"
echo "  $0 --verbose    # Verbose output"
echo "  $0 --logs       # Show errors from logs"
echo "  $0 --verbose --logs  # Full diagnostics"
echo ""
echo "Useful commands:"
echo "  docker compose -f docker-compose.yml -f docker-compose.mlnode.yml logs -f <container>  # View container logs"
echo "  docker logs \$(docker ps | grep <container> | awk '{print \$1}') -f  # Alternative"
echo "  curl http://localhost:${ADMIN_PORT}/admin/v1/nodes  # Node list"
echo "  curl http://localhost:${MLNODE_PORT}/api/v1/inference/up/status  # vLLM status"
echo "  curl http://localhost:${CHAIN_RPC_PORT}/status  # Chain node status"

