#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

DEBUG_MODE="${DEBUG_MODE:-0}"
if [[ "$DEBUG_MODE" == "1" ]]; then
    echo "[embed-build] DEBUG_MODE=1"
fi

source vulkan-sdk/setup-env.sh
echo "[embed-build] now building openblas ..."
DEBUG_MODE="$DEBUG_MODE" ./openblas/build.sh
echo "[embed-build] now building llama-cpp ..."
DEBUG_MODE="$DEBUG_MODE" ./llama-cpp/build.sh
echo "[embed-build] done"
