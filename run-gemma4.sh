#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export LD_LIBRARY_PATH="${SCRIPT_DIR}/target/lib:${LD_LIBRARY_PATH:-}"
export ROCBLAS_USE_HIPBLASLT="${ROCBLAS_USE_HIPBLASLT:-1}"
export TASK_PROFILE="${TASK_PROFILE:-reasoning}"
export GPU_LAYERS="${GPU_LAYERS:-999}"
export CTX_SIZE="${CTX_SIZE:-131072}"
export FLASH_ATTN="${FLASH_ATTN:-on}"
export WARMUP="${WARMUP:-on}"
export REASONING="${REASONING:-on}"
export OP_OFFLOAD="${OP_OFFLOAD:-on}"
export ENABLE_THINKING="${ENABLE_THINKING:-true}"
export TEMP_OVERRIDE="${TEMP_OVERRIDE:-1.0}"
export TOP_P_OVERRIDE="${TOP_P_OVERRIDE:-0.95}"
export TOP_K_OVERRIDE="${TOP_K_OVERRIDE:-64}"
export MIN_P_OVERRIDE="${MIN_P_OVERRIDE:-0.0}"
export PRESENCE_PENALTY_OVERRIDE="${PRESENCE_PENALTY_OVERRIDE:-1.0}"
export REPEAT_PENALTY_OVERRIDE="${REPEAT_PENALTY_OVERRIDE:-1.0}"

exec "${SCRIPT_DIR}/scripts/run-server.sh" \
    --binary-dir "${SCRIPT_DIR}/target/bin" \
    --model "${SCRIPT_DIR}/models/gemma-4-26B-A4B-it-UD-Q5_K_S.gguf" \
    --export-dir "${SCRIPT_DIR}/target"