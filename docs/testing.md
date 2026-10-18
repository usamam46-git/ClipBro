# Verification and acceptance

## Automated suites
- `scripts/test.sh`: deterministic core tests and URLProtocol-mocked AI tests. No live HTTP requests, real credentials or system clipboard access.
- `scripts/integration-test.sh`: AppKit named-pasteboard tests and Vision OCR of generated text. Requires access to macOS desktop services; the restricted agent sandbox fails its first pasteboard assertion, while the authorized host run passes. No general pasteboard mutations.
- `build/ClipBro.app/Contents/MacOS/ClipBro --ui-smoke-test`: launches a real NSPanel with synthetic memory-only history, does not start monitoring or load/write history, captures its own view to build/ui-preview.png, records build/ui-smoke.txt, then exits. Run from the repository root. Quit the ordinary app first to avoid hotkey contention. Optional --light, --dark, --emoji and --ai select presentation.

## Observed results
32 core checks and 12 AI checks pass. 12 native integration checks pass, including actual pasteboard generations, pause/resume, concealed marker handling, internal write suppression, multi-codepoint emoji, RTF-only decoding, file reference capture, exact PNG data and Vision OCR.
The app launched and remained running. A real panel became visible/key and the global shortcut registered without error. Its light and dark own-view screenshots were inspected; an internally posted down-arrow event moved selection in both appearances. This does not establish external app insertion or every interaction.
`xcodebuild` is unavailable: only Command Line Tools are installed. Swift compiler builds exit 0 using the installed macOS 26.5 SDK; macOS 27 CLT's SwiftUI SDK requires a missing macro plugin. The Xcode project is plist-valid but has not been built by Xcode.

## Manual acceptance ledger
| Requested check | Evidence / status |
|---|---|
| 21 clips / oldest eviction | Passed via real named pasteboard integration |
| Pinned retention / duplicate recency | Passed deterministic history tests |
| Global shortcut from another app | Registration passed; external keyboard invocation pending |
| Search, select, older-item copy | Search passed core tests; full interactive workflow pending |
| VS Code / browser insertion | Pending: user is granting ClipBro permission; the desktop automation host separately reports UI elements enabled=false |
| Denied paste fallback | Guard implemented; end-to-end fallback interaction pending |
| Multi-codepoint emoji | Capture and model roundtrip passed; destination insertion pending |
| Restart persistence | Serialization/load passed; full GUI restart retention pending |
| Live AI rewrite | Pending user-entered API key; no paid request made |
| Invalid key / rate-limit / failure | Mocked 401/429/500 and malformed/incomplete responses pass |
| No implicit AI request | Disabled/missing-key/input-cap tests send zero requests; network call site only explicit Send |
| Clearing persisted content | Passed persistence deletion test |
| Pause stops captures | Passed native pasteboard test |
| Themes / placement / keyboard | Light/dark rendering and arrow navigation passed own-view runtime smoke; multi-display and full interaction still need manual acceptance |
| Images / files / OCR | Passed synthetic native integration; third-party source-app variations pending |

## Suggested interactive check
Copy harmless fixture text in TextEdit, Chrome and VS Code. Press ⌘⇧V, search a word, use arrows, press ⌘C, and paste manually. Then enable automatic paste and explicitly grant Accessibility in Settings. Repeat from two apps and inspect actual inserted text; secure inputs may reject synthetic events. Try Notes as an additional target. Verify light/dark mode, Escape/outside dismissal, pins, emoji favorites and full-content sheets. Enter your API key only in ClipBro Settings and test a harmless rewrite.
