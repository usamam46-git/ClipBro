# Architecture
AppKit owns the menu bar, reusable NSPanel, settings window, global Carbon hotkey, and destination activation. SwiftUI composes native views with shared design tokens.
A pure Codable history model implements normalization, classification, recency and deterministic eviction. An observable main-thread store owns mutations. Atomic local persistence is serialized; pasteboard polling is changeCount gated. Internal writes update the monitor baseline.
Preferences use UserDefaults; API credentials use Keychain. A URLSession AI abstraction accepts only explicit requests. Vision OCR runs on demand. No REA runtime dependency, backend or cloud synchronization.
Future synchronization must implement an authenticated encrypted transport behind a separate interface; none is enabled.
