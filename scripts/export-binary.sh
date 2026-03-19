#!/usr/bin/env bash
set -euo pipefail

# Script to export binaries from Docker container
# Usage: export-binary.sh [--image NAME] [--export-dir DIR]

IMAGE="llama-gfx1151:latest"
EXPORT_DIR="./target"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image)
            IMAGE="$2"
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

echo "Exporting binaries from: $IMAGE"
echo "Export directory: $EXPORT_DIR"

mkdir -p "$EXPORT_DIR"

# Use docker-compose for consistency, fallback to podman
if [[ -f "docker-compose.yaml" ]]; then
    LLAMA_EXPORT_DIR="$EXPORT_DIR" podman-compose run --rm llama-gfx1151 /export
else
    podman run --rm \
        -v "$EXPORT_DIR:/export:Z" \
        -e LLAMA_EXPORT_DIR=/export \
        "$IMAGE" /export
fi

echo "Export completed successfully"
echo "Binaries location: $EXPORT_DIR"
