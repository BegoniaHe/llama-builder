#!/bin/bash
set -euo pipefail

# Ensure absolute path for LD_LIBRARY_PATH
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="${SCRIPT_DIR}/target/lib:${LD_LIBRARY_PATH:-}"

TASK_PROFILE="${TASK_PROFILE:-general}"

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

ROCBLAS_USE_HIPBLASLT=1 \
LD_LIBRARY_PATH="${SCRIPT_DIR}/target/lib:$LD_LIBRARY_PATH" \
"${SCRIPT_DIR}/target/bin/llama-server" \
  -m "${SCRIPT_DIR}/models/Qwen3.5-35B-A3B-UD-Q4_K_L.gguf" \
  -ngl 999 -c 131072 --parallel 1 \
  --temp "$TEMP" --top-p "$TOP_P" --top-k "$TOP_K" --min-p "$MIN_P" \
  --presence-penalty "$PRESENCE_PENALTY" --repeat-penalty "$REPEAT_PENALTY" --repeat-last-n 256 --flash-attn on \
  --chat-template-kwargs "{\"enable_thinking\": false}" \
  --host 0.0.0.0 --port 8000