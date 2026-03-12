#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-llama-gfx1151}"
EXPORT_DIR="${1:-${LLAMA_EXPORT_DIR:-$PWD/target}}"

mkdir -p "${EXPORT_DIR}"

echo "[export] image: ${IMAGE_NAME}"
echo "[export] output: ${EXPORT_DIR}"

podman run --rm -v "${EXPORT_DIR}:/export:Z" "${IMAGE_NAME}" /export

echo "[export] done"
ls -lh "${EXPORT_DIR}" | sed -n '1,120p'

# Display version info if available
if [[ -f "${EXPORT_DIR}/llama-git-rev.txt" ]]; then
    echo ""
    echo "[export] Exported version:"
    head -n 1 "${EXPORT_DIR}/llama-git-rev.txt" | xargs -I {} echo "  {}"
fi
