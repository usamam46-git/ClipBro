#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
codesign --verify --deep --strict build/ClipBro.app
mkdir -p build/dmg-stage
# The staging directory contains only generated release artifacts.
ditto build/ClipBro.app build/dmg-stage/ClipBro.app
if [[ ! -e build/dmg-stage/Applications ]]; then ln -s /Applications build/dmg-stage/Applications; fi
hdiutil create -volname ClipBro -srcfolder build/dmg-stage -ov -format UDZO build/ClipBro.dmg
ditto -c -k --sequesterRsrc --keepParent build/ClipBro.app build/ClipBro.zip
