#!/usr/bin/env bash
set -euo pipefail

# Script to run performance benchmarks
# Usage: benchmark.sh [--binary-dir DIR] [--model PATH] [--export-dir DIR] [--seq-lens LEN1,LEN2,...]

BINARY_DIR=""
MODEL_PATH=""
EXPORT_DIR=""
SEQ_LENS="4096,16384,65536"

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
        --seq-lens)
            SEQ_LENS="$2"
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

if [[ ! -f "$BINARY_DIR/llama-bench" ]]; then
    echo "Error: llama-bench not found at $BINARY_DIR/llama-bench" >&2
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

echo "Running performance benchmarks"
echo "  Model: $MODEL_PATH"
echo "  Sequence lengths: $SEQ_LENS"
echo "  GPU device: 0 (Strix Halo)"
echo ""

# Run with flash attention enabled
"$BINARY_DIR/llama-bench" \
    -m "$MODEL_PATH" \
    -fa 1 \
    -d 0 \
    -s "$SEQ_LENS"

echo ""
echo "Benchmark completed"
echo "  Results show throughput (tokens/sec) for prefill and decode phases"
