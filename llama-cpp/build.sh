#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

DEBUG_MODE="${DEBUG_MODE:-0}"
if [[ "$DEBUG_MODE" == "1" ]]; then
    BUILD_TYPE="RelWithDebInfo"
    GGML_LTO="OFF"
    EXTRA_DEBUG_FLAGS=(
        -DCMAKE_C_FLAGS_RELWITHDEBINFO="-O1 -g3 -fno-omit-frame-pointer"
        -DCMAKE_CXX_FLAGS_RELWITHDEBINFO="-O1 -g3 -fno-omit-frame-pointer"
        -DCMAKE_INSTALL_DO_STRIP=OFF
    )
    echo "[llama-build] DEBUG_MODE=1 -> CMAKE_BUILD_TYPE=${BUILD_TYPE}, GGML_LTO=${GGML_LTO}, keep symbols"
else
    BUILD_TYPE="Release"
    GGML_LTO="ON"
    EXTRA_DEBUG_FLAGS=()
fi

LLAMA_LLGUIDANCE="${LLAMA_LLGUIDANCE:-ON}"
if [[ "$LLAMA_LLGUIDANCE" == "ON" ]] && ! command -v cargo >/dev/null 2>&1; then
    echo "[llama-build] cargo not found, installing rustup ..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
    source "$HOME/.cargo/env"
fi

rm -rf build installed
mkdir build
cd build

cmake \
    -DCMAKE_INSTALL_PREFIX:PATH="$(realpath ../installed)" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DBUILD_SHARED_LIBS=ON \
    -DGGML_CPU=ON \
    -DGGML_CPU_ALL_VARIANTS=OFF \
    -DGGML_NATIVE=OFF \
    -DGGML_AVX=ON \
    -DGGML_SSE42=ON \
    -DGGML_AVX2=OFF \
    -DGGML_FMA=OFF \
    -DGGML_F16C=OFF \
    -DGGML_BMI2=OFF \
    -DGGML_AVX_VNNI=OFF \
    -DGGML_AVX512=OFF \
    -DGGML_AVX512_VBMI=OFF \
    -DGGML_AVX512_VNNI=OFF \
    -DGGML_AVX512_BF16=OFF \
    -DGGML_AMX_TILE=OFF \
    -DGGML_AMX_INT8=OFF \
    -DGGML_AMX_BF16=OFF \
    -DGGML_BLAS=ON \
    -DGGML_BLAS_VENDOR=OpenBLAS \
    -DGGML_VULKAN=ON \
    -DGGML_BACKEND_DL=ON \
    -DGGML_LTO="${GGML_LTO}" \
    -DLLAMA_LLGUIDANCE="${LLAMA_LLGUIDANCE}" \
    -DLLAMA_CURL=OFF \
    -DBLAS_LIBRARIES="$(realpath ../../openblas/installed/lib/libopenblas.so.0.3)" \
    -DBLAS_INCLUDE_DIRS="$(realpath ../../openblas/installed/include/)" \
    "${EXTRA_DEBUG_FLAGS[@]}" \
    ../src
cmake --build . --parallel 16
cmake --build . --target install

cd "$(realpath ../installed/lib)"
if [[ "$DEBUG_MODE" != "1" ]]; then
    echo "[llama-build] now striping ..."
    strip *.so
else
    echo "[llama-build] skip strip in DEBUG_MODE"
fi
echo "[llama-build] now chmoding ..."
chmod 0755 *.so
cd ../bin
chmod 0755 *.so
