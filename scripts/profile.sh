#!/usr/bin/env bash
set -euo pipefail

# Script to profile llama-cli with rocprofv3
# Usage: profile.sh [--binary-dir DIR] [--model PATH] [--export-dir DIR] [--output DIR]

BINARY_DIR=""
MODEL_PATH=""
EXPORT_DIR=""
OUTPUT_DIR="./profile-results"

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
        --output)
            OUTPUT_DIR="$2"
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

# Check for CLI binary
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

if ! command -v rocprofv3 &>/dev/null; then
    echo "Error: rocprofv3 not found. Please install ROCm development tools" >&2
    exit 1
fi

# Setup environment
export LD_LIBRARY_PATH="${EXPORT_DIR}/lib:${LD_LIBRARY_PATH:-}"
export ROCBLAS_USE_HIPBLASLT=1
export HSA_OVERRIDE_GFX_VERSION=11.0.0

mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PROFILE_DIR="$OUTPUT_DIR/profile_$TIMESTAMP"
mkdir -p "$PROFILE_DIR"

echo "🔍 Profiling with rocprofv3"
echo "  Binary: $CLI_BIN"
echo "  Model: $MODEL_PATH"
echo "  Output: $PROFILE_DIR"
echo ""
echo "This will collect GPU metrics. Press Ctrl+C to stop."
echo ""

# Create a simple prompt file if it doesn't exist
PROMPT_FILE="/tmp/llama_profile_prompt.txt"
echo "Tell me about machine learning." > "$PROMPT_FILE"

rocprofv3 \
    --output "$PROFILE_DIR/results" \
    "$CLI_BIN" \
    -m "$MODEL_PATH" \
    -ngl 999 \
    -n 20 \
    -c 512 \
    < "$PROMPT_FILE" || true

rm -f "$PROMPT_FILE"

echo ""
echo "✅ Profiling completed"
echo "  Results saved to: $PROFILE_DIR"
echo "  To analyze results, run: rocprofv3 --list-metrics"
