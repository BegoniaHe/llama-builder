#!/usr/bin/env bash
set -euo pipefail

MODEL_PATH="$PWD/models/Qwen3-Coder-Next-UD-IQ3_XXS.gguf"
PORT="${PORT:-8001}"
CTX_SIZE="${CTX_SIZE:-4096}"
N_GPU_LAYERS="${N_GPU_LAYERS:-30}"
EXPERT_OFFLOAD="${EXPERT_OFFLOAD:-none}"
CACHE_TYPE_K="${CACHE_TYPE_K:-q4_1}"
CACHE_TYPE_V="${CACHE_TYPE_V:-q4_1}"

OT_ARGS=()
if [[ "$EXPERT_OFFLOAD" == "all" ]]; then
  OT_ARGS=(-ot ".ffn_.*_exps.=CPU")
elif [[ "$EXPERT_OFFLOAD" == "updown" ]]; then
  OT_ARGS=(-ot ".ffn_(up|down)_exps.=CPU")
fi

ROCBLAS_USE_HIPBLASLT="${ROCBLAS_USE_HIPBLASLT:-0}" \
LD_LIBRARY_PATH="$PWD/target/lib:${LD_LIBRARY_PATH:-}" \
./target/bin/llama-server \
  -m "$MODEL_PATH" \
  -ngl "$N_GPU_LAYERS" -c "$CTX_SIZE" --parallel 1 --no-warmup \
  "${OT_ARGS[@]}" \
  --cache-type-k "$CACHE_TYPE_K" --cache-type-v "$CACHE_TYPE_V" \
  --fit on --flash-attn on \
  --temp 1.0 --top-p 0.95 --top-k 40 --min-p 0.01 \
  --repeat-penalty 1.0 --repeat-last-n 0 \
  --host 0.0.0.0 --port "$PORT"
