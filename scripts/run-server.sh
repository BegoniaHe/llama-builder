#!/usr/bin/env bash
set -euo pipefail

# Script to run llama-server with optimized settings for Strix Halo
# Usage: run-server.sh [--binary-dir DIR] [--model PATH] [--export-dir DIR] [--port PORT] [--host HOST]

BINARY_DIR=""
MODEL_PATH=""
EXPORT_DIR=""
PORT=8000
HOST="0.0.0.0"
GPU_LAYERS="${GPU_LAYERS:-999}"
CTX_SIZE="${CTX_SIZE:-131072}"
FLASH_ATTN="${FLASH_ATTN:-on}"
WARMUP="${WARMUP:-on}"
REASONING="${REASONING:-off}"
OP_OFFLOAD="${OP_OFFLOAD:-on}"
GFX_OVERRIDE="${GFX_OVERRIDE:-}"
TASK_PROFILE="${TASK_PROFILE:-general}"
ENABLE_THINKING="${ENABLE_THINKING:-false}"
TEMP_OVERRIDE="${TEMP_OVERRIDE:-}"
TOP_P_OVERRIDE="${TOP_P_OVERRIDE:-}"
TOP_K_OVERRIDE="${TOP_K_OVERRIDE:-}"
MIN_P_OVERRIDE="${MIN_P_OVERRIDE:-}"
PRESENCE_PENALTY_OVERRIDE="${PRESENCE_PENALTY_OVERRIDE:-}"
REPEAT_PENALTY_OVERRIDE="${REPEAT_PENALTY_OVERRIDE:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --binary-dir)
            BINARY_DIR="$2"
            shift 2
            ;;
        --model)
            MODEL_PATH="$2"
            shift 2
            ;;
        --export-dir)
            EXPORT_DIR="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --gpu-layers)
            GPU_LAYERS="$2"
            shift 2
            ;;
        --ctx-size)
            CTX_SIZE="$2"
            shift 2
            ;;
        --flash-attn)
            FLASH_ATTN="$2"
            shift 2
            ;;
        --warmup)
            WARMUP="$2"
            shift 2
            ;;
        --reasoning)
            REASONING="$2"
            shift 2
            ;;
        --op-offload)
            OP_OFFLOAD="$2"
            shift 2
            ;;
        --gfx-override)
            GFX_OVERRIDE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$BINARY_DIR" || -z "$MODEL_PATH" || -z "$EXPORT_DIR" ]]; then
    echo "Error: --binary-dir, --model, and --export-dir are required" >&2
    exit 1
fi

if [[ ! -f "$BINARY_DIR/llama-server" ]]; then
    echo "Error: llama-server not found at $BINARY_DIR/llama-server" >&2
    exit 1
fi

if [[ ! -f "$MODEL_PATH" ]]; then
    echo "Error: Model not found at $MODEL_PATH" >&2
    exit 1
fi

case "$TASK_PROFILE" in
    general)
        TEMP="0.7"
        TOP_P="0.8"
        TOP_K="20"
        MIN_P="0.0"
        PRESENCE_PENALTY="1.5"
        REPEAT_PENALTY="1.0"
        ;;
    reasoning)
        TEMP="1.0"
        TOP_P="0.95"
        TOP_K="20"
        MIN_P="0.0"
        PRESENCE_PENALTY="1.5"
        REPEAT_PENALTY="1.0"
        ;;
    *)
        echo "Unknown TASK_PROFILE: $TASK_PROFILE" >&2
        echo "Expected one of: general, reasoning" >&2
        exit 1
        ;;
esac

if [[ -n "$TEMP_OVERRIDE" ]]; then
    TEMP="$TEMP_OVERRIDE"
fi

if [[ -n "$TOP_P_OVERRIDE" ]]; then
    TOP_P="$TOP_P_OVERRIDE"
fi

if [[ -n "$TOP_K_OVERRIDE" ]]; then
    TOP_K="$TOP_K_OVERRIDE"
fi

if [[ -n "$MIN_P_OVERRIDE" ]]; then
    MIN_P="$MIN_P_OVERRIDE"
fi

if [[ -n "$PRESENCE_PENALTY_OVERRIDE" ]]; then
    PRESENCE_PENALTY="$PRESENCE_PENALTY_OVERRIDE"
fi

if [[ -n "$REPEAT_PENALTY_OVERRIDE" ]]; then
    REPEAT_PENALTY="$REPEAT_PENALTY_OVERRIDE"
fi

# Setup environment
export LD_LIBRARY_PATH="${EXPORT_DIR}/lib:${LD_LIBRARY_PATH:-}"
export ROCBLAS_USE_HIPBLASLT=1

if [[ -n "$GFX_OVERRIDE" ]]; then
    export HSA_OVERRIDE_GFX_VERSION="$GFX_OVERRIDE"
fi

echo "Starting llama-server"
echo "  Model: $MODEL_PATH"
echo "  Host: $HOST:$PORT"
echo "  GPU layers: $GPU_LAYERS"
echo "  Context: $CTX_SIZE"
echo "  Flash attention: $FLASH_ATTN"
echo "  Warmup: $WARMUP"
echo "  Reasoning: $REASONING"
echo "  Thinking: $ENABLE_THINKING"
echo "  Op offload: $OP_OFFLOAD"
echo "  Task profile: $TASK_PROFILE"
echo "  Temperature: $TEMP"
echo "  Top-p: $TOP_P"
echo "  Top-k: $TOP_K"
echo "  Min-p: $MIN_P"
echo "  Presence penalty: $PRESENCE_PENALTY"
echo "  Repeat penalty: $REPEAT_PENALTY"
if [[ -n "$GFX_OVERRIDE" ]]; then
    echo "  GFX override: $GFX_OVERRIDE"
fi
echo ""

ARGS=(
    -m "$MODEL_PATH"
    -c "$CTX_SIZE"
    --parallel 1
    --temp "$TEMP"
    --top-p "$TOP_P"
    --top-k "$TOP_K"
    --min-p "$MIN_P"
    --presence-penalty "$PRESENCE_PENALTY"
    --repeat-penalty "$REPEAT_PENALTY"
    --repeat-last-n 256
    --flash-attn "$FLASH_ATTN"
    --chat-template-kwargs "{\"enable_thinking\": ${ENABLE_THINKING}}"
    --host "$HOST"
    --port "$PORT"
)

ARGS+=( -ngl "$GPU_LAYERS" )

if [[ "$WARMUP" == "off" ]]; then
    ARGS+=(--no-warmup)
else
    ARGS+=(--warmup)
fi

if [[ "$OP_OFFLOAD" == "off" ]]; then
    ARGS+=(--no-op-offload)
fi

exec "$BINARY_DIR/llama-server" "${ARGS[@]}"
