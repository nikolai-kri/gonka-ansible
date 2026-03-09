#!/bin/bash

# Script to check where model parameters come from
# Shows configuration from different sources

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
NODE_CONFIG=${NODE_CONFIG:-./node-config.json}

echo "Node configuration check"
echo "========================"
echo ""

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found. Install jq for the script to work."
    exit 1
fi

# 1. Check node-config.json
echo "1. Configuration from node-config.json:"
if [ -f "$NODE_CONFIG" ]; then
    echo "$(cat "$NODE_CONFIG" | jq '.')"
else
    echo "  File not found: $NODE_CONFIG"
fi
echo ""

# 2. Check Admin API
echo "2. Configuration from Admin API (localhost:${ADMIN_PORT}):"
if curl -s -f "${ADMIN_URL}/admin/v1/nodes" > /dev/null 2>&1; then
    NODES_JSON=$(curl -s "${ADMIN_URL}/admin/v1/nodes" 2>/dev/null || echo "[]")
    if echo "$NODES_JSON" | jq empty 2>/dev/null; then
        echo "$NODES_JSON" | jq '.'
    else
        echo "  Error: Could not get valid JSON"
        echo "$NODES_JSON"
    fi
else
    echo "  Admin API unavailable"
fi
echo ""

# 3. Check SQLite DB (if available)
echo "3. Configuration from SQLite DB:"
# Check several possible paths
SQLITE_PATHS=(
    "./.dapi/gonka.db"
    "./gonka.db"
    "${API_SQLITE_PATH:-}"
)

SQLITE_FOUND=false
for SQLITE_PATH in "${SQLITE_PATHS[@]}"; do
    if [ -n "$SQLITE_PATH" ] && [ -f "$SQLITE_PATH" ]; then
        echo "  ✓ DB found: $SQLITE_PATH"
        SQLITE_FOUND=true
        
        # Check for sqlite3
        if command -v sqlite3 &> /dev/null; then
            echo ""
            echo "  Contents of inference_nodes table:"
            sqlite3 "$SQLITE_PATH" "SELECT id, models_json FROM inference_nodes;" 2>/dev/null | while IFS='|' read -r id models_json; do
                echo "  Node ID: $id"
                echo "$models_json" | jq '.' 2>/dev/null || echo "    $models_json"
            done
        else
            echo "  sqlite3 not found. Install it to view contents."
            echo "  Or use:"
            echo "    docker exec api sqlite3 /root/.dapi/gonka.db 'SELECT id, models_json FROM inference_nodes;' | jq '.'"
        fi
        break
    fi
done

if [ "$SQLITE_FOUND" = false ]; then
    echo "  DB not found in standard locations."
    echo "  Check:"
    echo "    - ./.dapi/gonka.db"
    echo "    - ./gonka.db"
    echo "    - Or environment variable API_SQLITE_PATH"
    echo ""
    echo "  Or check inside api container:"
    echo "    docker exec api ls -la /root/.dapi/"
    echo "    docker exec api sqlite3 /root/.dapi/gonka.db 'SELECT id, models_json FROM inference_nodes;' | jq '.'"
fi
echo ""

# 4. Where parameters come from when starting vLLM
echo "4. Where parameters come from when starting vLLM:"
echo ""
echo "  When starting automatically via API (InferenceUpNodeCommand):"
echo "    - epochModel.ModelArgs (from blockchain governance) - PRIORITY!"
echo "    - localArgs (from Admin API / SQLite DB)"
echo "    - Merged via MergeModelArgs (epochArgs take priority)"
echo ""
echo "  When starting manually via start_vllm.sh:"
echo "    - Reads from node-config.json"
echo "    - Sends directly to MLNode API"
echo "    - Does NOT use MergeModelArgs"
echo ""
echo "  ⚠️  ISSUE: If blockchain governance has --max-model-len 40960,"
echo "     local args from Admin API will NOT be able to override it!"
echo ""
echo "  Solution: Check what is in epochModel.ModelArgs"
echo "           (this is the value from blockchain governance for the model)"
echo ""

# 5. Current situation analysis
echo "5. Current situation analysis:"
echo ""

# Check if we have data from Admin API
if [ -n "$NODES_JSON" ] && echo "$NODES_JSON" | jq empty 2>/dev/null; then
    # Check for empty args
    if echo "$NODES_JSON" | jq -e '.[0].node.models."Qwen/Qwen3-32B-FP8".args | length == 0' > /dev/null 2>&1; then
        echo "  ⚠️  ISSUE DETECTED:"
        echo "     Admin API args are empty: []"
        echo ""
        echo "  This means:"
        echo "    1. Update via update_node_max_model_len.sh did not persist args"
        echo "    2. Or args were empty when updating"
        echo ""
        echo "  Check SQLite DB (see section 3 above)"
        echo "  If DB is also empty, the update was not applied."
        echo ""
        echo "  Solution:"
        echo "    1. Ensure update_node_max_model_len.sh ran successfully"
        echo "    2. Check api container logs for errors"
        echo "    3. Try updating again:"
        echo "       ./update_node_max_model_len.sh node14 Qwen/Qwen3-32B-FP8 16384 0.95"
        echo ""
    fi
    
    # Check epoch_models for ModelArgs
    EPOCH_MODEL_ARGS=$(echo "$NODES_JSON" | jq -r '.[0].state.epoch_models."Qwen/Qwen3-32B-FP8".model_args // empty' 2>/dev/null || echo "")
    if [ -n "$EPOCH_MODEL_ARGS" ] && [ "$EPOCH_MODEL_ARGS" != "null" ]; then
        echo "  ⚠️  WARNING: epoch_models has ModelArgs from governance:"
        echo "     $EPOCH_MODEL_ARGS"
        echo ""
        echo "  These args take PRIORITY over local args!"
    else
        echo "  ✓ No ModelArgs in epoch_models (or they are empty)"
        echo "    Default max_model_len from model config (40960) is used"
    fi
fi

