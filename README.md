# ClipBro
Native macOS clipboard history, emoji and opt-in text assistance. SwiftUI + AppKit, macOS 14+, no third-party runtime packages.

## Build
Run `./scripts/build.sh`, then open `build/ClipBro.app`. Full Xcode users can open `ClipBro.xcodeproj` and build the ClipBro scheme. The command-line fallback uses Apple's Swift compiler and ad-hoc signing. This is a local development build, not a notarized release.

Run `./scripts/test.sh` for deterministic tests without reading the system clipboard or making network requests.

Implementation and verification status: [docs/progress.md](docs/progress.md).
