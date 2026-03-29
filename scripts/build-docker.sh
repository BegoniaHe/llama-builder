#!/usr/bin/env bash
set -euo pipefail

# Script to build Docker image with optimized settings
# Usage: build-docker.sh [--image NAME] [--ref REF] [--context DIR] [--pgo-stage none|generate] [--no-cache]

IMAGE="llama-gfx1151"
REF="master"
CONTEXT="."
PGO_STAGE="none"
NO_CACHE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image)
            IMAGE="$2"
            shift 2
            ;;
        --ref)
            REF="$2"
            shift 2
            ;;
        --context)
            CONTEXT="$2"
            shift 2
            ;;
        --pgo-stage)
            PGO_STAGE="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

echo "Building Docker image: $IMAGE"
echo "  Reference: $REF"
echo "  Context: $CONTEXT"
echo "  PGO stage: $PGO_STAGE"

podman build \
    ${NO_CACHE:+--no-cache} \
    -t "$IMAGE" \
    --build-arg "LLAMA_CPP_REF=$REF" \
    --build-arg "PGO_STAGE=$PGO_STAGE" \
    "$CONTEXT" \
    --no-cache

echo "Docker image built successfully: $IMAGE"
