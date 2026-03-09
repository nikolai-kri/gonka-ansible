#!/bin/bash

# Script to update max-model-len via Admin API
# Usage: ./update_node_max_model_len.sh <node_id> <model_name> <max_model_len> [gpu_memory_utilization]

set -e

# Load environment variables
if [ -f config.env ]; then
    source config.env
else
    echo "Error: config.env not found"
    exit 1
fi

ADMIN_PORT=${DAPI_API__ADMIN_SERVER_PORT:-9200}
ADMIN_URL="http://localhost:${ADMIN_PORT}"

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <node_id> <model_name> <max_model_len> [gpu_memory_utilization]"
    echo ""
    echo "Examples:"
    echo "  $0 node14 Qwen/Qwen3-32B-FP8 16384"
    echo "  $0 node14 Qwen/Qwen3-32B-FP8 16384 0.95"
    echo ""
    echo "Parameters:"
    echo "  node_id              - Node ID (e.g. node14)"
    echo "  model_name           - Model name (e.g. Qwen/Qwen3-32B-FP8)"
    echo "  max_model_len        - Max sequence length (e.g. 16384, 8192)"
    echo "  gpu_memory_utilization - Optional: GPU memory utilization (e.g. 0.95)"
    exit 1
fi

NODE_ID="$1"
MODEL_NAME="$2"
MAX_MODEL_LEN="$3"
GPU_MEM_UTIL="${4:-}"

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found. Install jq for the script to work."
    exit 1
fi

echo "Updating node configuration via Admin API"
echo "=========================================="
echo "Node ID: $NODE_ID"
echo "Model: $MODEL_NAME"
echo "Max Model Len: $MAX_MODEL_LEN"
if [ -n "$GPU_MEM_UTIL" ]; then
    echo "GPU Memory Utilization: $GPU_MEM_UTIL"
fi
echo "Admin API: $ADMIN_URL"
echo ""

# Check Admin API availability
echo -n "Checking Admin API availability... "
if ! curl -s -f "${ADMIN_URL}/admin/v1/nodes" > /dev/null 2>&1; then
    echo "ERROR"
    echo "Admin API unavailable at ${ADMIN_URL}"
    echo "Ensure api container is running:"
    echo "  docker compose -f docker-compose.yml -f docker-compose.mlnode.yml ps | grep api"
    exit 1
fi
echo "OK"
echo ""

# Get current node configuration
echo "Fetching current node configuration..."
NODES_JSON=$(curl -s "${ADMIN_URL}/admin/v1/nodes" 2>/dev/null || echo "[]")

# Check response is valid JSON
if ! echo "$NODES_JSON" | jq empty 2>/dev/null; then
    echo "Error: Could not get valid JSON from Admin API"
    echo "Response:"
    echo "$NODES_JSON"
    exit 1
fi

# Check response type
RESPONSE_TYPE=$(echo "$NODES_JSON" | jq -r 'type' 2>/dev/null)
if [ "$RESPONSE_TYPE" != "array" ]; then
    echo "Error: Expected array, got type: $RESPONSE_TYPE"
    echo "Response:"
    echo "$NODES_JSON" | jq '.'
    exit 1
fi

# Check array is not empty
ARRAY_LENGTH=$(echo "$NODES_JSON" | jq 'length' 2>/dev/null)
if [ "$ARRAY_LENGTH" = "0" ]; then
    echo "Error: Node array is empty"
    exit 1
fi

# Determine response format (node/state or flat)
FIRST_ITEM=$(echo "$NODES_JSON" | jq '.[0]' 2>/dev/null)
HAS_NODE_FIELD=$(echo "$FIRST_ITEM" | jq -r 'if type == "object" then has("node") | tostring else "false" end' 2>/dev/null)

# Find node
if [ "$HAS_NODE_FIELD" = "true" ]; then
    # Format: [{"node": {...}, "state": {...}}]
    NODE_JSON=$(echo "$NODES_JSON" | jq --arg node_id "$NODE_ID" '.[] | select(.node.id == $node_id)' 2>/dev/null)
else
    # Format: [{...}] - flat node array
    NODE_JSON=$(echo "$NODES_JSON" | jq --arg node_id "$NODE_ID" '.[] | select(.id == $node_id)' 2>/dev/null)
fi

# Check node was found
if [ -z "$NODE_JSON" ] || [ "$NODE_JSON" = "null" ] || [ "$NODE_JSON" = "" ]; then
    echo "Error: Node '$NODE_ID' not found"
    echo ""
    echo "Available nodes:"
    if [ "$HAS_NODE_FIELD" = "true" ]; then
        echo "$NODES_JSON" | jq -r '.[].node.id // empty' 2>/dev/null | while read id; do
            [ -n "$id" ] && echo "  - $id"
        done
    else
        echo "$NODES_JSON" | jq -r '.[].id // empty' 2>/dev/null | while read id; do
            [ -n "$id" ] && echo "  - $id"
        done
    fi
    exit 1
fi

echo "✓ Node found"
echo ""

# Extract current configuration
if [ "$HAS_NODE_FIELD" = "true" ]; then
    CURRENT_NODE=$(echo "$NODE_JSON" | jq '.node' 2>/dev/null)
else
    CURRENT_NODE=$(echo "$NODE_JSON" | jq '.' 2>/dev/null)
fi

# Check CURRENT_NODE is an object
if ! echo "$CURRENT_NODE" | jq -e 'type == "object"' > /dev/null 2>&1; then
    echo "Error: Could not extract node configuration"
    echo "NODE_JSON:"
    echo "$NODE_JSON" | jq '.'
    exit 1
fi

# Check for models field
if ! echo "$CURRENT_NODE" | jq -e 'has("models")' > /dev/null 2>&1; then
    echo "Error: Node configuration has no 'models' field"
    echo "CURRENT_NODE:"
    echo "$CURRENT_NODE" | jq '.'
    exit 1
fi

# Check model exists
MODEL_EXISTS=$(echo "$CURRENT_NODE" | jq -r --arg model "$MODEL_NAME" '
    if .models | type == "object" then
        .models | has($model) | tostring
    else
        "false"
    end
')

if [ "$MODEL_EXISTS" != "true" ]; then
    echo "Error: Model '$MODEL_NAME' not found in node '$NODE_ID'"
    echo ""
    echo "Available models:"
    if echo "$CURRENT_NODE" | jq -e '.models | type == "object"' > /dev/null 2>&1; then
        echo "$CURRENT_NODE" | jq -r '.models | keys[]' 2>/dev/null | while read model; do
            [ -n "$model" ] && echo "  - $model"
        done
    else
        echo "  (models is not an object)"
    fi
    exit 1
fi

echo "✓ Model found"
echo ""

# Get current model args
CURRENT_ARGS=$(echo "$CURRENT_NODE" | jq -r --arg model "$MODEL_NAME" '
    if .models[$model] | type == "object" and has("args") then
        .models[$model].args // []
    else
        []
    end
')

echo "Current model args:"
if [ -n "$CURRENT_ARGS" ] && [ "$CURRENT_ARGS" != "null" ]; then
    echo "$CURRENT_ARGS" | jq -r 'if type == "array" then .[] else empty end' 2>/dev/null | while read arg; do
        [ -n "$arg" ] && echo "  $arg"
    done
    if [ -z "$(echo "$CURRENT_ARGS" | jq -r 'if type == "array" then .[] else empty end' 2>/dev/null | head -1)" ]; then
        echo "  (empty)"
    fi
else
    echo "  (empty)"
fi
echo ""

# Update args: remove old max-model-len and gpu-memory-utilization, add new ones
# Ensure CURRENT_ARGS is an array
if ! echo "$CURRENT_ARGS" | jq -e 'type == "array"' > /dev/null 2>&1; then
    CURRENT_ARGS="[]"
fi

UPDATED_ARGS=$(echo "$CURRENT_ARGS" | jq -r --arg max_len "$MAX_MODEL_LEN" --arg gpu_util "$GPU_MEM_UTIL" '
    # Ensure it is an array
    if type != "array" then [] else . end |
    # Build new array, skipping old params and their values
    . as $args |
    reduce range(length) as $i ([]; 
        $args[$i] as $arg |
        if $i > 0 and ($args[$i-1] == "--max-model-len" or $args[$i-1] == "--gpu-memory-utilization") then
            # Skip value after param
            .
        elif $arg == "--max-model-len" or $arg == "--gpu-memory-utilization" then
            # Skip the param itself
            .
        else
            # Add remaining args
            . + [$arg]
        end
    ) |
    # Append new params
    . + ["--max-model-len", $max_len] |
    if $gpu_util != "" then
        . + ["--gpu-memory-utilization", $gpu_util]
    else
        .
    end
')

echo "New model args:"
echo "$UPDATED_ARGS" | jq -r '.[]' | while read arg; do
    echo "  $arg"
done
echo ""

# Build updated node configuration
UPDATED_NODE=$(echo "$CURRENT_NODE" | jq --arg model "$MODEL_NAME" --argjson args "$UPDATED_ARGS" '
    .models[$model].args = $args |
    {
        id: .id,
        host: .host,
        inference_segment: (if .inference_segment then .inference_segment else "" end),
        inference_port: .inference_port,
        poc_segment: (if .poc_segment then .poc_segment else "" end),
        poc_port: .poc_port,
        max_concurrent: .max_concurrent,
        models: .models,
        hardware: (if .hardware then .hardware else [] end)
    }
')

echo "Sending updated configuration..."
echo ""

# Send update via PUT
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X PUT \
    -H "Content-Type: application/json" \
    -d "$UPDATED_NODE" \
    "${ADMIN_URL}/admin/v1/nodes/${NODE_ID}" 2>/dev/null || echo -e "\n000")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Node configuration updated successfully!"
    echo ""
    echo "Updated configuration:"
    if command -v jq &> /dev/null; then
        echo "$BODY" | jq '.'
    else
        echo "$BODY"
    fi
    echo ""
    echo "⚠️  IMPORTANT: After updating configuration you need to restart vLLM:"
    echo ""
    echo "  1. Stop current vLLM (if running):"
    echo "     curl -X POST http://localhost:8080/api/v1/inference/down"
    echo ""
    echo "  2. Wait a few seconds"
    echo "     sleep 5"
    echo ""
    echo "  3. Start vLLM with new configuration:"
    echo "     ./start_vllm.sh $NODE_ID $MODEL_NAME"
    echo ""
    echo "  Or simply (uses first node from node-config.json):"
    echo "     ./start_vllm.sh"
    echo ""
    echo "  4. Check status:"
    echo "     curl http://localhost:8080/api/v1/inference/up/status | jq '.'"
else
    echo "✗ Error updating configuration (HTTP $HTTP_CODE)"
    echo ""
    echo "Server response:"
    if command -v jq &> /dev/null; then
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
    else
        echo "$BODY"
    fi
    exit 1
fi

