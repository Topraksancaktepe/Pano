#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/work/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/work/swift-cache"
exec swift "$@" --disable-sandbox --scratch-path "$ROOT_DIR/work/build" --cache-path "$ROOT_DIR/work/package-cache" --config-path "$ROOT_DIR/work/package-config" --security-path "$ROOT_DIR/work/package-security"
