#!/bin/bash

# Script to start vLLM via MLNode API
# Usage: ./start_vllm.sh [node_id] [model_name]

set -e

# Load environment variables
if [ -f config.env ]; then
    source config.env
else
    echo "Error: config.env not found"
    exit 1
fi

MLNODE_PORT=${PORT:-8080}
NODE_CONFIG=${NODE_CONFIG:-./node-config.json}

# Check for node-config.json
if [ ! -f "$NODE_CONFIG" ]; then
    echo "Error: $NODE_CONFIG not found"
    exit 1
fi

# Parse node-config.json to get node information
echo "Reading configuration from $NODE_CONFIG..."

# Get first node from config (can be extended to select a specific node)
NODE_ID=$(jq -r '.[0].id // empty' "$NODE_CONFIG" 2>/dev/null || echo "")
MODEL_NAME=$(jq -r '.[0].models | keys[0] // empty' "$NODE_CONFIG" 2>/dev/null || echo "")

# Override via arguments
if [ -n "$1" ]; then
    NODE_ID="$1"
fi

if [ -n "$2" ]; then
    MODEL_NAME="$2"
fi

if [ -z "$NODE_ID" ] || [ -z "$MODEL_NAME" ]; then
    echo "Error: Could not determine NODE_ID or MODEL_NAME"
    echo "Usage: $0 [node_id] [model_name]"
    echo ""
    echo "Or specify in node-config.json"
    exit 1
fi

echo "NODE_ID: $NODE_ID"
echo "MODEL_NAME: $MODEL_NAME"
echo "MLNode API: http://localhost:${MLNODE_PORT}"

# Check MLNode API availability
echo -n "Checking MLNode API availability... "
MLNODE_AVAILABLE=false

# Try different endpoints
for endpoint in "/docs" "/health" "/api/v1/health" "/inference/up/status" ""; do
    if curl -s -f --max-time 3 "http://localhost:${MLNODE_PORT}${endpoint}" > /dev/null 2>&1; then
        MLNODE_AVAILABLE=true
        break
    fi
done

if [ "$MLNODE_AVAILABLE" = false ]; then
    echo "ERROR"
    echo "MLNode API is not available on port ${MLNODE_PORT}"
    echo ""
    echo "Check:"
    echo "  1. Container mlnode-308 is running:"
    echo "     docker compose -f docker-compose.yml -f docker-compose.mlnode.yml ps | grep mlnode"
    echo ""
    echo "  2. Port ${MLNODE_PORT} is open:"
    echo "     netstat -tuln | grep ${MLNODE_PORT} || ss -tuln | grep ${MLNODE_PORT}"
    echo ""
    echo "  3. Container logs:"
    echo "     docker compose -f docker-compose.yml -f docker-compose.mlnode.yml logs mlnode-308 | tail -20"
    echo "     or find container:"
    echo "     docker ps | grep mlnode"
    echo "     docker logs \$(docker ps | grep mlnode | awk '{print \$1}') | tail -20"
    exit 1
fi
echo "OK"

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found. Install jq for the script to work."
    exit 1
fi

# Get model arguments from config
MODEL_ARGS=$(jq -r --arg model "$MODEL_NAME" '.[0].models[$model].args // [] | join(" ")' "$NODE_CONFIG" 2>/dev/null || echo "")

# Check for GPU memory tuning parameters
# If the model is large and GPU memory for KV cache is insufficient, add parameters
if echo "$MODEL_ARGS" | grep -qv "max-model-len\|gpu-memory-utilization"; then
    echo ""
    echo "⚠️  WARNING: The model may require GPU memory tuning."
    echo "   If you get the error 'max seq len is larger than KV cache',"
    echo "   add to node-config.json in the model args:"
    echo ""
    echo "   For limited memory (~18K tokens KV cache):"
    echo "   --max-model-len 16384 --gpu-memory-utilization 0.95"
    echo ""
    echo "   For very limited memory:"
    echo "   --max-model-len 8192 --gpu-memory-utilization 0.95"
    echo ""
    echo "   See DIAGNOSTICS.md section 'Error: max seq len is larger than KV cache'"
fi

# Build JSON request
if [ -n "$MODEL_ARGS" ]; then
    # Has arguments - split into array
    REQUEST_JSON=$(jq -n \
        --arg model "$MODEL_NAME" \
        --arg args "$MODEL_ARGS" \
        '{
            "model": $model,
            "dtype": "auto",
            "additional_args": ($args | split(" ") | map(select(. != "")))
        }')
else
    # No arguments
    REQUEST_JSON=$(jq -n \
        --arg model "$MODEL_NAME" \
        '{
            "model": $model,
            "dtype": "auto",
            "additional_args": []
        }')
fi

echo ""
echo "vLLM start request:"
echo "$REQUEST_JSON" | jq '.'

# Start vLLM (async)
echo ""
echo "Sending vLLM start request..."
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$REQUEST_JSON" \
    "http://localhost:${MLNODE_PORT}/api/v1/inference/up/async" 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ vLLM is starting in the background"
    echo ""
    echo "Server response:"
    if command -v jq &> /dev/null; then
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    else
        echo "$BODY"
    fi
    echo ""
    echo "To check status use:"
    echo "  curl http://localhost:${MLNODE_PORT}/api/v1/inference/up/status"
    echo ""
    echo "Or run diagnostics:"
    echo "  ./diagnose.sh --verbose"
    echo ""
    echo "Note: vLLM startup may take several minutes depending on model size."
elif [ "$HTTP_CODE" = "409" ]; then
    echo "⚠ vLLM is already running or starting"
    echo ""
    echo "Server response:"
    if command -v jq &> /dev/null; then
        echo "$BODY" | jq -r '.detail // .message // .' 2>/dev/null || echo "$BODY"
    else
        echo "$BODY"
    fi
    echo ""
    echo "Check status:"
    echo "  curl http://localhost:${MLNODE_PORT}/api/v1/inference/up/status"
    echo ""
    echo "To restart, stop first:"
    echo "  curl -X POST http://localhost:${MLNODE_PORT}/api/v1/inference/down"
else
    echo "✗ Error starting vLLM (HTTP $HTTP_CODE)"
    echo ""
    echo "Server response:"
    if command -v jq &> /dev/null; then
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    else
        echo "$BODY"
    fi
    echo ""
    echo "Check MLNode logs:"
    echo "  docker compose -f docker-compose.yml -f docker-compose.mlnode.yml logs mlnode-308 | tail -50"
    echo "  or:"
    echo "  docker logs \$(docker ps | grep mlnode | awk '{print \$1}') | tail -50"
    exit 1
fi

