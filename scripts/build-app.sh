#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
export CLANG_MODULE_CACHE_PATH="$TASK_ROOT/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$TASK_ROOT/.build/module-cache"
TASK_SWIFT_ARGS=(--disable-sandbox --configuration release --arch arm64 --scratch-path "$TASK_ROOT/.build" --cache-path "$TASK_ROOT/.build/cache" --config-path "$TASK_ROOT/.build/config" --security-path "$TASK_ROOT/.build/security" -debug-info-format none)
swift build "${TASK_SWIFT_ARGS[@]}" -Xswiftc -warnings-as-errors
TASK_BIN_PATH="$(swift build "${TASK_SWIFT_ARGS[@]}" --show-bin-path)"
python3 "$TASK_ROOT/scripts/bundle-app.py" "$TASK_BIN_PATH/TouchMe"
