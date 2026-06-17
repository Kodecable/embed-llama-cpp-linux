#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

DEBUG_MODE="${DEBUG_MODE:-0}"
if [[ "$DEBUG_MODE" == "1" ]]; then
    BUILD_TYPE="RelWithDebInfo"
    echo "[openblas-build] DEBUG_MODE=1 -> CMAKE_BUILD_TYPE=${BUILD_TYPE}, keep symbols"
else
    BUILD_TYPE="Release"
fi

rm -rf build installed
mkdir build
cd build

cmake \
    --toolchain=/usr/share/steamrt/cmake/gcc-14.cmake \
    -DCMAKE_INSTALL_PREFIX:PATH="$(realpath ../installed)" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DDYNAMIC_ARCH=TRUE \
    -DTARGET=SANDYBRIDGE \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=OFF \
    -DNO_AFFINITY=ON \
    -DNUM_THREADS=32 \
    -DNO_WARMUP=1 \
    ../src
cmake --build . --parallel 16
cmake --build . --target install

cd "$(realpath ../installed/lib)"
if [[ "$DEBUG_MODE" != "1" ]]; then
    echo "[openblas-build] now striping ..."
    strip *.so
else
    echo "[openblas-build] skip strip in DEBUG_MODE"
fi
echo "[openblas-build] now chmoding ..."
chmod 0755 *.so
