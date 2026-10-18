#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
mkdir -p build/module-cache
swiftc -sdk "$CLIPBRO_SDK" -swift-version 5 -module-cache-path build/module-cache ClipBro/Models/*.swift ClipBro/Services/ClipboardMonitor.swift ClipBro/Services/MediaService.swift ClipBroTests/ClipboardIntegrationTests.swift -o build/ClipboardIntegrationTests
build/ClipboardIntegrationTests
