#!/usr/bin/env bash
set -euo pipefail

# Script to run llama-server with optimized settings for Strix Halo
# Usage: run-server.sh [--binary-dir DIR] [--model PATH] [--export-dir DIR] [--port PORT] [--host HOST]

BINARY_DIR=""
MODEL_PATH=""
EXPORT_DIR=""
PORT=8000
HOST="0.0.0.0"

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

# Setup environment
export LD_LIBRARY_PATH="${EXPORT_DIR}/lib:${LD_LIBRARY_PATH:-}"
export ROCBLAS_USE_HIPBLASLT=1
export HSA_OVERRIDE_GFX_VERSION=11.0.0

echo "Starting llama-server"
echo "  Model: $MODEL_PATH"
echo "  Host: $HOST:$PORT"
echo "  GPU layers: 999"
echo "  Context: 131072"
echo ""

exec "$BINARY_DIR/llama-server" \
    -m "$MODEL_PATH" \
    -ngl 999 \
    -c 131072 \
    --parallel 1 \
    --temp 0.80 \
    --top-p 0.90 \
    --top-k 30 \
    --min-p 0.00 \
    --repeat-penalty 1.05 \
    --repeat-last-n 256 \
    --flash-attn on \
    --chat-template-kwargs '{"enable_thinking": false}' \
    --host "$HOST" \
    --port "$PORT"
