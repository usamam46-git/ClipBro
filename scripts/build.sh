#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ClipBro.app/Contents/MacOS build/module-cache
sources=()
while IFS= read -r file; do sources+=("$file"); done < <(find ClipBro -name '*.swift' -type f | sort)
swiftc -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path build/module-cache "${sources[@]}" -o build/ClipBro.app/Contents/MacOS/ClipBro
cp ClipBro/Resources/Info.plist build/ClipBro.app/Contents/Info.plist
codesign --force --sign - build/ClipBro.app
printf 'Built %s/build/ClipBro.app\n' "$PWD"
