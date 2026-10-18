# Architecture
AppKit owns the menu bar, reusable NSPanel, settings window, global Carbon hotkey, and destination activation. SwiftUI composes native views with shared design tokens.
A pure Codable history model implements normalization, classification, recency and deterministic eviction. An observable main-thread store owns mutations. Atomic local persistence is serialized; pasteboard polling is changeCount gated. Internal writes update the monitor baseline.
Preferences use UserDefaults; API credentials use Keychain. A URLSession AI abstraction accepts only explicit requests. Vision OCR runs on demand. No REA runtime dependency, backend or cloud synchronization.
Future synchronization must implement an authenticated encrypted transport behind a separate interface; none is enabled.

## Rich clipboard storage
Images are embedded as Codable binary data in the atomic history document. This deliberately avoids orphaned asset files at the default small history size. The configurable image budget is at most 50 MB, individual images at most 8 MB and 40 million pixels, and total raw content is capped at 64 MB. JSON base64 expands binary size; loading rejects files over 128 MB. Old unpinned entries are evicted first; pinned content is never silently discarded to satisfy a storage cap. Thumbnail cache is bounded to 12 MB. RTF is capped at 2 MB/item. File references retain up to 100 URLs, not copied file contents; inaccessible files cause a copy error with a path-copy fallback.
Vision text recognition is explicit and runs off the main thread. Extracted text remains in the detail preview until saved.
