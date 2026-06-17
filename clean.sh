#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

rm -rf output
rm -rf openblas/build
rm -rf openblas/installed
rm -rf llama-cpp/build
rm -rf llama-cpp/installed
