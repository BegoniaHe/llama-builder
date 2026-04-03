#!/usr/bin/env just --justfile

set shell := ["bash", "-euo", "pipefail"]
set dotenv-load := false

# Project root
PROJECT_ROOT := justfile_directory()
SCRIPTS_DIR := PROJECT_ROOT / "scripts"

# Docker configuration
DOCKER_IMAGE := "llama-gfx1151:latest"
DOCKER_TAG := "llama-gfx1151"
LLAMA_CPP_REF := env_var_or_default("LLAMA_CPP_REF", "master")
LLAMA_EXPORT_DIR := env_var_or_default("LLAMA_EXPORT_DIR", PROJECT_ROOT / "target")

# Model paths
QWEN3_5_MODEL_PATH := PROJECT_ROOT / "models" / "Qwen3.5-35B-A3B-UD-Q4_K_L.gguf"
GEMMA4_MODEL_PATH := PROJECT_ROOT / "models" / "gemma-4-26B-A4B-it-UD-Q5_K_S.gguf"
MODEL_PATH := QWEN3_5_MODEL_PATH
BENCH_MODEL := env_var_or_default("BENCH_MODEL", MODEL_PATH)

# Help command
help:
    just --list

# Build Docker image
[doc("Build Docker image for llama-gfx1151")]
build:
    #!/bin/bash
    echo "Building Docker image: {{DOCKER_TAG}}"
    "{{SCRIPTS_DIR}}/build-docker.sh" --image "{{DOCKER_TAG}}" --ref "{{LLAMA_CPP_REF}}" --context "{{PROJECT_ROOT}}"

# Build without cache
[doc("Build Docker image without cache")]
build-nocache:
    #!/bin/bash
    echo "Building Docker image (no-cache): {{DOCKER_TAG}}"
    "{{SCRIPTS_DIR}}/build-docker.sh" --image "{{DOCKER_TAG}}" --ref "{{LLAMA_CPP_REF}}" --context "{{PROJECT_ROOT}}" --no-cache

# Build PGO instrumentation image
[doc("Build a PGO instrumentation image for profile collection")]
build-pgo-generate:
    #!/bin/bash
    echo "Building PGO instrumentation image: {{DOCKER_TAG}}-pgo-generate"
    "{{SCRIPTS_DIR}}/build-docker.sh" --image "{{DOCKER_TAG}}-pgo-generate" --ref "{{LLAMA_CPP_REF}}" --context "{{PROJECT_ROOT}}" --pgo-stage generate

# Export binaries
[doc("Export compiled binaries from Docker")]
export:
    #!/bin/bash
    echo "Exporting binaries to {{LLAMA_EXPORT_DIR}}"
    mkdir -p "{{LLAMA_EXPORT_DIR}}"
    "{{SCRIPTS_DIR}}/export-binary.sh" --image "{{DOCKER_TAG}}" --export-dir "{{LLAMA_EXPORT_DIR}}"

# Run llama-server
[doc("Start llama-server with model profile: just run qwen3_5 | just run gemma4")]
run model="qwen3_5": check-binary
    #!/bin/bash
    case "{{model}}" in
        qwen3_5)
            echo "Starting llama-server for qwen3_5..."
            exec "{{PROJECT_ROOT}}/run-qwen3_5.sh"
            ;;
        gemma4)
            echo "Starting llama-server for gemma4..."
            exec "{{PROJECT_ROOT}}/run-gemma4.sh"
            ;;
        *)
            echo "Unknown model '{{model}}'. Expected one of: qwen3_5, gemma4" >&2
            exit 1
            ;;
    esac

# Run llama-server with a CPU-oriented fallback that avoids the current ROCm op-offload crash.
[doc("Start llama-server with CPU fallback to avoid current ROCm segfault")]
run-safe: check-binary
    #!/bin/bash
    echo "Starting llama-server in safe mode..."
    GPU_LAYERS=0 OP_OFFLOAD=off FLASH_ATTN=off CTX_SIZE=512 WARMUP=off REASONING=off \
        "{{SCRIPTS_DIR}}/run-server.sh" --binary-dir "{{LLAMA_EXPORT_DIR}}/bin" --model "{{MODEL_PATH}}" --export-dir "{{LLAMA_EXPORT_DIR}}"

# Run CLI
[doc("Start llama-cli interactive mode")]
run-cli: check-binary
    #!/bin/bash
    echo "Starting llama-cli..."
    "{{SCRIPTS_DIR}}/run-cli.sh" --binary-dir "{{LLAMA_EXPORT_DIR}}/bin" --model "{{MODEL_PATH}}" --export-dir "{{LLAMA_EXPORT_DIR}}"

# Run benchmarks
[doc("Run performance benchmarks")]
bench: check-binary
    #!/bin/bash
    echo "Running benchmarks..."
    "{{SCRIPTS_DIR}}/benchmark.sh" --binary-dir "{{LLAMA_EXPORT_DIR}}/bin" --model "{{BENCH_MODEL}}" --export-dir "{{LLAMA_EXPORT_DIR}}"

# Profile with rocprofv3
[doc("Profile with rocprofv3")]
profile: check-binary
    #!/bin/bash
    echo "Profiling with rocprofv3..."
    "{{SCRIPTS_DIR}}/profile.sh" --binary-dir "{{LLAMA_EXPORT_DIR}}/bin" --model "{{MODEL_PATH}}" --export-dir "{{LLAMA_EXPORT_DIR}}"

# Check build status
[doc("Check build status and version")]
check-build:
    #!/bin/bash
    if [[ -f "{{LLAMA_EXPORT_DIR}}/llama-git-rev.txt" ]]; then
        echo "Build found at {{LLAMA_EXPORT_DIR}}"
        echo "Git revision: $(cat '{{LLAMA_EXPORT_DIR}}/llama-git-rev.txt' | cut -c1-7)"
        echo "Binaries:"
        ls -lh "{{LLAMA_EXPORT_DIR}}/bin" 2>/dev/null | tail -n +2 | awk '{print "  " $9 " (" $5 ")"}'
    else
        echo "No build found. Run 'just build && just export' first."
    fi

# Run tests
[doc("Run basic tests")]
test: check-binary
    #!/bin/bash
    echo "Running tests..."
    "{{SCRIPTS_DIR}}/test.sh" --binary-dir "{{LLAMA_EXPORT_DIR}}/bin" --model "{{MODEL_PATH}}" --export-dir "{{LLAMA_EXPORT_DIR}}"

# Clean build artifacts
[doc("Clean build artifacts")]
clean:
    #!/bin/bash
    echo "Cleaning build artifacts..."
    rm -rf "{{LLAMA_EXPORT_DIR}}"
    echo "Cleaned {{LLAMA_EXPORT_DIR}}"

# Clean everything
[doc("Clean all including Docker images")]
clean-all: clean
    #!/bin/bash
    echo "Removing Docker images..."
    if podman image inspect "{{DOCKER_TAG}}" &>/dev/null; then
        podman rmi -f "{{DOCKER_TAG}}" && echo "Removed {{DOCKER_TAG}}"
    else
        echo "{{DOCKER_TAG}} not found"
    fi

# Check if binary exists
[private]
check-binary:
    #!/bin/bash
    if [[ ! -f "{{LLAMA_EXPORT_DIR}}/bin/llama-server" ]] && [[ ! -f "{{LLAMA_EXPORT_DIR}}/bin/llama-cli" ]]; then
        echo "Binary not found. Run 'just build && just export' first."
        exit 1
    fi

# Full build pipeline
[doc("Full build pipeline: docker build → export")]
all: build export check-build
    #!/bin/bash
    echo "Build pipeline completed!"

# Rebuild everything from scratch
[doc("Clean and rebuild everything")]
rebuild: clean-all all
    #!/bin/bash
    echo "Rebuild completed!"
