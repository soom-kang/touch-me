#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
export CLANG_MODULE_CACHE_PATH="$TASK_ROOT/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$TASK_ROOT/.build/module-cache"
TASK_SWIFT_BIN="$(dirname "$(xcrun --find swiftc)")"
TASK_TESTING_PLUGIN="$TASK_SWIFT_BIN/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
TASK_PLUGIN_FLAGS=()
if [[ -f "$TASK_TESTING_PLUGIN" ]]; then
    TASK_PLUGIN_FLAGS=(-Xswiftc -load-plugin-library -Xswiftc "$TASK_TESTING_PLUGIN")
fi
swift test --disable-sandbox --disable-xctest --enable-swift-testing --configuration release --arch arm64 --scratch-path "$TASK_ROOT/.build" --cache-path "$TASK_ROOT/.build/cache" --config-path "$TASK_ROOT/.build/config" --security-path "$TASK_ROOT/.build/security" -debug-info-format none -Xswiftc -warnings-as-errors "${TASK_PLUGIN_FLAGS[@]}"
