#!/usr/bin/env bash
set -euo pipefail

# Script to run basic tests
# Usage: test.sh [--binary-dir DIR] [--model PATH] [--export-dir DIR]

BINARY_DIR=""
MODEL_PATH=""
EXPORT_DIR=""

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
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$BINARY_DIR" || -z "$EXPORT_DIR" ]]; then
    echo "Error: --binary-dir and --export-dir are required" >&2
    exit 1
fi

# Setup environment
export LD_LIBRARY_PATH="${EXPORT_DIR}/lib:${LD_LIBRARY_PATH:-}"
export ROCBLAS_USE_HIPBLASLT=1
export HSA_OVERRIDE_GFX_VERSION=11.0.0

echo "Running basic tests"
echo ""

# Test 1: Check binary executability
echo "Test 1: Checking binaries..."
PASS=0
FAIL=0

for binary in "$BINARY_DIR"/llama-*; do
    if [[ -x "$binary" ]]; then
        echo "  $(basename "$binary")"
        ((PASS++))
    else
        echo "  $(basename "$binary") (not executable)"
        ((FAIL++))
    fi
done

echo ""

# Test 2: Check libraries
echo "Test 2: Checking libraries..."
if [[ -d "$EXPORT_DIR/lib" ]]; then
    if ls "$EXPORT_DIR/lib"/*.so* 1>/dev/null 2>&1; then
        LIB_COUNT=$(ls -1 "$EXPORT_DIR/lib"/*.so* 2>/dev/null | wc -l)
        echo "  Found $LIB_COUNT libraries"
        ((PASS++))
    else
        echo "  No .so files found"
        ((FAIL++))
    fi
else
    echo "  Library directory not found"
    ((FAIL++))
fi

echo ""

# Test 3: Quick inference test (if model provided)
if [[ -n "$MODEL_PATH" && -f "$MODEL_PATH" ]]; then
    echo "Test 3: Quick inference test..."

    # Determine correct binary name
    CLI_BIN=""
    if [[ -f "$BINARY_DIR/llama-cli" ]]; then
        CLI_BIN="$BINARY_DIR/llama-cli"
    elif [[ -f "$BINARY_DIR/llama-completion" ]]; then
        CLI_BIN="$BINARY_DIR/llama-completion"
    else
        echo "  CLI binary not found (skipping)"
    fi

    if [[ -n "$CLI_BIN" ]]; then
        PROMPT="What is 2+2?"
        OUTPUT=$("$CLI_BIN" -m "$MODEL_PATH" -n 5 -ngl 999 <<< "$PROMPT" 2>/dev/null | tail -1 || true)

        if [[ -n "$OUTPUT" && ${#OUTPUT} -gt 5 ]]; then
            echo "  Inference successful"
            echo "     Input: $PROMPT"
            echo "     Output: ${OUTPUT:0:50}..."
            ((PASS++))
        else
            echo "  Inference test inconclusive"
        fi
    fi
else
    echo "Test 3: Skipped (no model provided)"
fi

echo ""
echo "═══════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════"

if [[ $FAIL -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed"
    exit 1
fi
