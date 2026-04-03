#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export LD_LIBRARY_PATH="${SCRIPT_DIR}/target/lib:${LD_LIBRARY_PATH:-}"
export ROCBLAS_USE_HIPBLASLT="${ROCBLAS_USE_HIPBLASLT:-1}"
export TASK_PROFILE="${TASK_PROFILE:-general}"
export GPU_LAYERS="${GPU_LAYERS:-999}"
export CTX_SIZE="${CTX_SIZE:-131072}"
export FLASH_ATTN="${FLASH_ATTN:-on}"
export WARMUP="${WARMUP:-on}"
export REASONING="${REASONING:-off}"
export OP_OFFLOAD="${OP_OFFLOAD:-on}"

exec "${SCRIPT_DIR}/scripts/run-server.sh" \
    --binary-dir "${SCRIPT_DIR}/target/bin" \
    --model "${SCRIPT_DIR}/models/Qwen3.5-35B-A3B-UD-Q4_K_L.gguf" \
    --export-dir "${SCRIPT_DIR}/target"