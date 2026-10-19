# ClipBro progress

| Feature | Status | Verification method | Commit | Push | Known limitations |
|---|---|---|---|---|---|
| Environment and native foundation | Implemented | Swift build exit 0; plist validation; real app launch | 477dedf | pushed | Full Xcode absent |
| Clipboard history, dedup, pins, search, management | Implemented | Core tests and named-pasteboard integration | eff621a | pushed | Polling can miss changes faster than 350 ms; bounded content |
| Global shortcut, paste handling, native settings | Implemented | Registration + visible/key panel smoke checks; internal arrow event passed | eff621a | pushed | Cross-app insertion pending permission/testing; app-local conflicts possible |
| Emoji picker | Implemented | Compile, Unicode roundtrip, dataset uniqueness/search | eff621a | pushed | Curated subset; favorites UI not manually exercised |
| AI transformations and Keychain | Implemented | 12 mocked HTTP checks; compile | 5902084 | pushed | Live API and actual credential storage require user-entered key |
| Images, files, RTF and local OCR | Implemented | 32 core checks + 12 real native integration checks | bc76740 | pushed | Image/file caps; file URLs can expire; RTF not all source formats |
| Keyboard reliability, custom icons and appearance | Verified local build | Light/dark screenshots inspected; panel key and arrow movement true | a3f6c67 | pushed | Multi-display and comprehensive GUI acceptance pending |
| Privacy and accessibility preferences | Implemented | Safeguard tests; AppKit permission check | a3f6c67 | pushed | Secret heuristic imperfect; user granting Accessibility |
| Packaging | Complete | codesign verification exit 0; DMG and ZIP generated | a3f6c67 | pushed | Ad-hoc signed, not notarized |
| REA investigation | Blocked, documented | Actual CLI doctor: registration missing; no MCP tools | 477dedf | pushed | No reference-app observations or decompilation evidence |
| Xcode build | Blocked | Actual xcodebuild invocation exits 1: full Xcode required | — | — | Xcode project is plist-valid; compiler fallback succeeds |
| Sync and import/export | Deferred | No implementation claimed | — | — | Optional scope; no backend enabled |

## Test totals
- 32 deterministic core checks passed.
- 12 AI checks passed with URLProtocol mock; zero live API requests.
- 12 native integration checks passed outside the restricted sandbox, using a private pasteboard and synthetic OCR image.
- Light/dark runtime smoke reports: panelVisible=true, panelKey=true, arrowNavigated=true, no hotkey registration error.

See [testing.md](testing.md) for the acceptance ledger and remaining interactive checks. Build artifacts and synthetic screenshots remain ignored under build/. No API key, clipboard history or user settings are committed.

## Delivery
All five feature milestones are committed and pushed to origin/main. Local build/ClipBro.app (about 1.7 MB), build/ClipBro.dmg and build/ClipBro.zip were generated and the app signature verified. The ordinary app was reopened for user permission setup. No release or repository-visibility change was made.

## Startup and permission discovery fix
The user reported that opening the app appeared to do nothing and ClipBro was absent from Accessibility. Process inspection initially found no running instance; a fresh launch stayed alive. The previous build defaulted to silent startup and did not handle Finder reopen events. The permission request was available only inside Shortcuts settings.
Fixed: visible first-run setup window, panel-on-launch default for new preferences, Finder reopen handling, menu-bar paste-setup action, explicit Accessibility setup button, live permission status on app reactivation, current app path and Finder reveal with manual-add instructions. No permission is granted programmatically.
Verification: Swift build exit 0; 32 core and 12 AI tests pass; settings smoke reports settingsVisible=true and the setup view was inspected. Cross-app paste remains unverified.

## Launcher interaction repair
User reported an inert menu icon and shortcut after the startup fix. One installed process was present; a one-second stack sample showed its main thread idle in the AppKit event loop, not blocked. Replaced the nonactivating/auto-hidden panel plus asynchronous outside-click monitor with an explicitly activated key panel and application-deactivation dismissal. Menu-button and Carbon actions defer presentation until their event dispatch completes; a visible but unfocused panel is raised instead of toggled away.
Verification: compiler build and 44 core/AI checks pass. Isolated real NSStatusBarButton action and registered Carbon handler tests report menuActionVisible, hotkeyCloses, hotkeyOpens, hotkeyRegistered, transientFocusRetained, escapeDismisses and reopenVisible all true. These test Carbon dispatch, not physical global key delivery. After installing and reopening /Applications/ClipBro.app, WindowServer reports an on-screen 560×640 ClipBro window at layer 3. User confirmation of physical menu click and shortcut has been requested. No clipboard content was recorded by diagnostics.
