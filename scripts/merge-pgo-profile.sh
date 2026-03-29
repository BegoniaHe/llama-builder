#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Usage: $0 <profraw-dir> <output.profdata> [image]" >&2
    exit 1
fi

PROFRAW_DIR="$1"
OUTPUT_FILE="$2"
IMAGE_NAME="${3:-llama-gfx1151-pgo-generate}"

if [[ ! -d "$PROFRAW_DIR" ]]; then
    echo "Profile directory not found: $PROFRAW_DIR" >&2
    exit 1
fi

if ! find "$PROFRAW_DIR" -maxdepth 1 -name '*.profraw' -print -quit | grep -q .; then
    echo "No .profraw files found in: $PROFRAW_DIR" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
OUTPUT_ABS="$(cd "$(dirname "$OUTPUT_FILE")" && pwd)/$(basename "$OUTPUT_FILE")"
PROFRAW_ABS="$(cd "$PROFRAW_DIR" && pwd)"

echo "[pgo] merging raw profiles from: $PROFRAW_ABS"
echo "[pgo] output: $OUTPUT_ABS"
echo "[pgo] image: $IMAGE_NAME"

podman run --rm \
    --entrypoint /usr/bin/llvm-profdata \
    -v "$PROFRAW_ABS:/profiles:Z" \
    "$IMAGE_NAME" \
    merge -output="/profiles/$(basename "$OUTPUT_ABS")" /profiles/*.profraw

echo "[pgo] merged profile written to: $OUTPUT_ABS"