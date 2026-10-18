#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk -swift-version 5 -module-cache-path build/module-cache ClipBro/Models/*.swift ClipBro/Services/HistoryPersistence.swift ClipBro/Services/ClipboardMonitor.swift ClipBro/Services/MediaService.swift ClipBroTests/CoreTests.swift -o build/CoreTests
build/CoreTests
swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk -swift-version 5 -module-cache-path build/module-cache ClipBro/Models/Preferences.swift ClipBro/Services/AIService.swift ClipBroTests/AITests.swift -o build/AITests
build/AITests
