#!/usr/bin/env bash
set -euo pipefail

# Script to run llama-cli for interactive prompt
# Usage: run-cli.sh [--binary-dir DIR] [--model PATH] [--export-dir DIR] [--threads N]

BINARY_DIR=""
MODEL_PATH=""
EXPORT_DIR=""
THREADS=${THREADS:-$(nproc)}

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
        --threads)
            THREADS="$2"
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

# Determine correct binary name (may be llama-cli or llama-completion)
CLI_BIN=""
if [[ -f "$BINARY_DIR/llama-cli" ]]; then
    CLI_BIN="$BINARY_DIR/llama-cli"
elif [[ -f "$BINARY_DIR/llama-completion" ]]; then
    CLI_BIN="$BINARY_DIR/llama-completion"
else
    echo "Error: llama-cli not found in $BINARY_DIR" >&2
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

echo "💬 Starting llama-cli"
echo "  Model: $MODEL_PATH"
echo "  GPU layers: 999"
echo "  Threads: $THREADS"
echo ""

exec "$CLI_BIN" \
    -m "$MODEL_PATH" \
    -ngl 999 \
    -t "$THREADS" \
    -c 4096 \
    --temp 0.70 \
    --top-p 0.90 \
    --flash-attn on
