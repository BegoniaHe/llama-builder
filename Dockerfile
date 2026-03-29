FROM rocm/dev-ubuntu-24.04:7.2-complete

ENV DEBIAN_FRONTEND=noninteractive

ENV ROCM_PATH=/opt/rocm \
    HIP_PATH=/opt/rocm

RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake build-essential clang \
    ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

ARG LLAMA_CPP_REPO=https://github.com/BegoniaHe/llama.cpp.git
ARG LLAMA_CPP_REF=master
ARG PGO_STAGE=none
RUN git clone ${LLAMA_CPP_REPO} --depth 1 --branch ${LLAMA_CPP_REF} /workspace/llama.cpp
WORKDIR /workspace/llama.cpp

RUN HIPCXX="$(hipconfig -l)/clang" \
 && case "$PGO_STAGE" in \
        none) \
            PGO_C_FLAGS=""; \
            PGO_CXX_FLAGS=""; \
            PGO_EXE_LINKER_FLAGS=""; \
            ;; \
        generate) \
            PGO_C_FLAGS="-fprofile-instr-generate"; \
            PGO_CXX_FLAGS="-fprofile-instr-generate"; \
            PGO_EXE_LINKER_FLAGS="-fprofile-instr-generate"; \
            ;; \
        *) \
            echo "Unsupported PGO_STAGE: $PGO_STAGE" >&2; \
            exit 1; \
            ;; \
    esac \
 && cmake -S . -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_HIP_COMPILER="$HIPCXX" \
      -DHIP_PLATFORM=amd \
      -DGGML_HIP=ON \
      -DAMDGPU_TARGETS=gfx1151 \
      -DGGML_HIP_ROCWMMA_FATTN=ON \
      -DGGML_NATIVE=ON \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
      -DCMAKE_HIP_FLAGS="-mllvm --amdgpu-unroll-threshold-local=600" \
      -DBUILD_SHARED_LIBS=OFF \
      -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=ON \
    -DLLAMA_BUILD_TOOLS=ON \
      -DLLAMA_BUILD_SERVER=ON \
      -DCMAKE_C_FLAGS="-O3 -ffunction-sections -fdata-sections ${PGO_C_FLAGS}" \
      -DCMAKE_CXX_FLAGS="-O3 -ffunction-sections -fdata-sections ${PGO_CXX_FLAGS}" \
      -DCMAKE_EXE_LINKER_FLAGS="-no-pie -Wl,--gc-sections ${PGO_EXE_LINKER_FLAGS}" \
      -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--gc-sections" \
 && cmake --build build --config Release -j"$(nproc)"

RUN cat >/usr/local/bin/export-llama-gfx1151 <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

EXPORT_DIR="${1:-${LLAMA_EXPORT_DIR:-/export}}"

mkdir -p "${EXPORT_DIR}" "${EXPORT_DIR}/bin" "${EXPORT_DIR}/lib"

cp -af /workspace/llama.cpp/build/bin/. "${EXPORT_DIR}/bin/"

if [[ -f /workspace/llama.cpp/build/bin/llama-completion ]]; then
    cp -f /workspace/llama.cpp/build/bin/llama-completion "${EXPORT_DIR}/bin/llama-cli"
fi

cp -f /workspace/llama.cpp/build/ggml/src/ggml-hip/libggml-hip.a "${EXPORT_DIR}/"
cp -f /workspace/llama.cpp/build/src/libllama.a "${EXPORT_DIR}/"

# Store current git revision
CURRENT_GIT_REV="$(git -C /workspace/llama.cpp rev-parse HEAD)"
git -C /workspace/llama.cpp rev-parse HEAD > "${EXPORT_DIR}/llama-git-rev.txt"

copy_rocm_lib_from_ldd() {
    local binary="$1"
    ldd "${binary}" 2>/dev/null | awk '
        /=> \/opt\/rocm/ { print $3 }
        /^\/opt\/rocm/    { print $1 }
    ' | sort -u | while read -r lib; do
        [[ -z "${lib}" ]] && continue
        local real
        real="$(readlink -f "${lib}" || true)"
        [[ -z "${real}" || ! -f "${real}" ]] && continue

        cp -f "${real}" "${EXPORT_DIR}/lib/"

        local lib_base real_base
        lib_base="$(basename "${lib}")"
        real_base="$(basename "${real}")"
        if [[ "${lib_base}" != "${real_base}" ]]; then
            ln -sf "${real_base}" "${EXPORT_DIR}/lib/${lib_base}"
        fi
    done
}

for binary in /workspace/llama.cpp/build/bin/*; do
    [[ -x "${binary}" && -f "${binary}" ]] || continue
    copy_rocm_lib_from_ldd "${binary}"
done

cp -af /opt/rocm/lib/rocblas "${EXPORT_DIR}/lib/"

# Check if current build is the latest version from upstream
echo ""
echo "Built from: ${CURRENT_GIT_REV}"

# Try to fetch the latest commit hash from upstream
if LATEST_GIT_REV="$(git -C /workspace/llama.cpp ls-remote origin HEAD | awk '{print $1}' 2>/dev/null)" && [[ -n "${LATEST_GIT_REV}" ]]; then
    if [[ "${CURRENT_GIT_REV}" == "${LATEST_GIT_REV}" ]]; then
        echo "Status: Up-to-date with upstream (${CURRENT_GIT_REV:0:7})"
    else
        echo "Status: Not the latest version"
        echo "Latest:  ${LATEST_GIT_REV:0:7}"
        echo "Built:   ${CURRENT_GIT_REV:0:7}"
        echo "To update, rebuild with the latest code"
    fi
else
    echo "Status: Could not fetch upstream version info"
    echo "Built from: ${CURRENT_GIT_REV:0:7}"
fi
echo ""

echo "Export completed to: ${EXPORT_DIR}"
ls -lh "${EXPORT_DIR}" | sed -n '1,120p'
echo "---"
ls -lh "${EXPORT_DIR}/bin" | sed -n '1,200p'

if [[ "${PGO_STAGE:-none}" == "generate" ]]; then
    echo "---"
    echo "PGO collection build exported."
    echo "Run binaries with LLVM_PROFILE_FILE pointing to a writable .profraw path."
fi
EOF

RUN chmod +x /usr/local/bin/export-llama-gfx1151

ENV HSA_OVERRIDE_GFX_VERSION=11.0.0 \
    ROCBLAS_USE_HIPBLASLT=1 \
    PGO_STAGE=${PGO_STAGE}

ENTRYPOINT ["/usr/local/bin/export-llama-gfx1151"]
CMD ["/export"]
