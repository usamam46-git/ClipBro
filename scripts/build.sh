#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
mkdir -p build/ClipBro.app/Contents/MacOS build/module-cache
sources=()
while IFS= read -r file; do sources+=("$file"); done < <(find ClipBro -name '*.swift' -type f | sort)
swiftc -sdk "$CLIPBRO_SDK" -swift-version 5 -O -target arm64-apple-macosx14.0 -module-cache-path build/module-cache "${sources[@]}" -o build/ClipBro.app/Contents/MacOS/ClipBro
mkdir -p build/ClipBro.app/Contents/Resources
cp ClipBro/Resources/AppIcon.icns build/ClipBro.app/Contents/Resources/
cp ClipBro/Resources/Info.plist build/ClipBro.app/Contents/Info.plist
codesign --force --sign - build/ClipBro.app
printf 'Built %s/build/ClipBro.app\n' "$PWD"
