# ClipBro

A native, local-first macOS clipboard companion with a floating glass panel, searchable history, emoji, and optional AI text assistance. Built with SwiftUI and AppKit, targeting macOS 14+ on Apple Silicon. No third-party runtime dependencies.

## Run

1. Run `./scripts/build.sh` from this repository.
2. Open `build/ClipBro.app`, or copy it into Applications first for a stable path.
3. Click the clipboard face in the menu bar or press **⌘⇧V**.

Left-click opens the panel. Right-click offers Open, Settings, Pause Monitoring and Quit. The app runs without a Dock icon. The first launch starts with empty history and does not capture pre-existing clipboard contents.

The local app is **ad-hoc signed, not Developer ID signed or notarized**. Gatekeeper and organizational policy may require user approval. Login-item and Accessibility behavior should be tested after installing at a stable path. Rebuilding an ad-hoc app can require renewed permission.

## Use

- Copy text, URLs, images, rich text or files in another app. Recent history defaults to 20 unpinned items; duplicates move to the top. Pins have a separate limit.
- Search text, titles, labels or source-app names. Arrow keys select; Enter copies by default. Enable automatic paste in Settings if desired.
- **⌘C** or the row copy action always copies only. Selected search text retains ordinary text-copy behavior. **⌘F** focuses search; **Escape** dismisses.
- Right-click a clip for pinning, plain-text activation, deletion, AI transformation or full content/title editing. Image details offer local **Extract Text** via Vision.
- The Emoji tab includes a curated Unicode collection, categories, recent use and favorites. Right-click to favorite; arrows and Enter navigate/activate.
- The AI tab previews editable input before **Send to OpenAI**. It offers 25 actions, result copy/save, opt-in titles, and replacement that pins the original for recovery.

## AI setup

Open Settings → AI, enable AI, enter your OpenAI API key in the secure field and save it to Keychain. Do not put the key in source files or chat. The configurable default is `gpt-4.1-mini`; access depends on your API account. API billing is separate. Each Send action submits only the displayed input. There are no automatic transformations or clipboard-history uploads.

The implementation follows the official [text generation guide](https://developers.openai.com/api/docs/guides/text) and uses the [Responses API](https://developers.openai.com/api/docs/guides/responses). `store:false` is set; provider retention policies still apply.

## Build and test

```sh
./scripts/build.sh
./scripts/test.sh
./scripts/integration-test.sh
```

The core/AI suite uses deterministic fixtures and mocked HTTP. The native integration suite uses a private named pasteboard, generated images and Vision, leaving the system clipboard untouched. Desktop-service access is required for integration tests.

Open `ClipBro.xcodeproj` in full Xcode, or run:

```sh
xcodebuild -project ClipBro.xcodeproj -scheme ClipBro -configuration Debug -derivedDataPath build/DerivedData build
```

This host has only Command Line Tools, so **the Xcode build is unverified**. The project and plist pass `plutil` validation. The Swift fallback build succeeds using the installed macOS 26.5 SDK because the host's macOS 27 CLT SDK lacks a required SwiftUI macro plugin. `CLIPBRO_SDK` can override SDK selection. Regenerate the checked-in project after adding sources with `python3 scripts/generate-project.py`.

`./scripts/package.sh` builds an unsigned-for-distribution DMG and ZIP under `build/`. It requires disk-image service access. No GitHub release is published.

## Privacy and limits

History lives in `~/Library/Application Support/ClipBro/history.json` with owner-only permissions. API credentials live in Keychain. History is not application-encrypted. Persistence can be disabled; items and all history can be deleted. Concealed/transient clipboard types are excluded; source-app exclusions and optional secret heuristics help but do not guarantee secret exclusion.

Monitoring checks changeCount every 350 ms with timer tolerance; multiple copies between polls may be missed. Text is capped at 1 MB/item, RTF at 2 MB/item, images at 8 MB/item and 40 megapixels. The configurable image budget is up to 50 MB and total raw history content is capped at 64 MB. Binary content is embedded in the atomic history file, so deleting entries removes their stored data without orphan files. Pins are retained when budgets shrink; new captures may be refused until space is freed.

File references retain URLs, not file contents, and can become inaccessible. Rich-text support preserves RTF, not every proprietary pasteboard format. Emoji coverage is curated. Source-app attribution is a foreground-app inference.

Automatic paste needs **System Settings → Privacy & Security → Accessibility → ClipBro**. Copy-only does not. Some apps and secure fields reject synthetic input; successful event posting cannot establish insertion. No permission is bypassed.

Cross-device synchronization and import/export are not implemented. Universal paste compatibility, App Store sandboxing, Developer ID signing and notarization are outside this local build.

See [verification and manual acceptance](docs/testing.md), [progress](docs/progress.md), [architecture](docs/architecture.md), [security](docs/security.md), and the [bounded REA investigation](docs/rea-findings.md).

### If opening ClipBro appears to do nothing
The first launch now opens setup. Opening the running app again brings its panel or settings forward. You can also use ⌘⇧V or the menu-bar icon. In Settings → Shortcuts, **Set Up Automatic Paste…** requests Accessibility and opens its settings pane. If ClipBro is absent, use **+**, press **⇧⌘G**, and select `/Applications/ClipBro.app` (or the exact path shown by ClipBro). Enable its switch, then enable **Paste into the previous app** in ClipBro. Copy-only remains usable without permission.
