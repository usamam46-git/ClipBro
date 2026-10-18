import AppKit

protocol ClipboardReading {
    var changeCount: Int { get }
    var typeNames: [String] { get }
    func readText() -> String?
}
extension NSPasteboard: ClipboardReading {
    var typeNames: [String] { (types ?? []).map(\.rawValue) }
    func readText() -> String? { string(forType: .string) ?? string(forType: .URL) }
}
struct ClipboardGate {
    private(set) var lastChange: Int
    init(changeCount: Int) { lastChange = changeCount }
    mutating func changed(_ count: Int) -> Bool {
        guard count != lastChange else { return false }
        lastChange = count
        return true
    }
    mutating func ignore(_ count: Int) { lastChange = count }
}
@MainActor
final class ClipboardMonitor {
    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var gate: ClipboardGate
    var receive: ((ClipItem) -> Void)?
    var preferences: () -> Preferences = { Preferences() }
    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        gate = ClipboardGate(changeCount: pasteboard.changeCount)
    }
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer?.tolerance = 0.1
    }
    func stop() { timer?.invalidate(); timer = nil }
    func ignoreCurrent() { gate.ignore(pasteboard.changeCount) }
    func poll() {
        let observedCount = pasteboard.changeCount
        guard gate.changed(observedCount) else { return }
        let prefs = preferences()
        guard prefs.monitoring, !PrivacyFilter.shouldIgnore(types: pasteboard.typeNames) else { return }
        let app = NSWorkspace.shared.frontmostApplication
        let excluded = prefs.excludedApps.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !excluded.contains(app?.bundleIdentifier ?? "") else { return }
        var item: ClipItem
        if let files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !files.isEmpty {
            let urls = Array(files.prefix(100))
            item = ClipItem(text: urls.map(\.path).joined(separator: "\n"), kind: .file)
            item.fileURLs = urls.map(\.absoluteString)
        } else if let text = pasteboard.readText(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard text.utf8.count <= 1_000_000, !prefs.skipSensitive || !PrivacyFilter.likelySecret(text) else { return }
            item = ClipItem(text: text, kind: Classifier.classify(text))
            if let rtf = pasteboard.data(forType: .rtf), rtf.count <= 2_000_000 { item.richText = rtf }
        } else if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff), MediaService.validImage(data) {
            item = ClipItem(text: "Copied image", kind: .image)
            item.imageData = data
            item.imageType = pasteboard.availableType(from: [.png, .tiff])?.rawValue
        } else if let rtf = pasteboard.data(forType: .rtf), rtf.count <= 2_000_000,
                  let attributed = try? NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            let text = attributed.string
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 1_000_000,
                  !prefs.skipSensitive || !PrivacyFilter.likelySecret(text) else { return }
            item = ClipItem(text: text, kind: Classifier.classify(text))
            item.richText = rtf
        } else { return }
        // Do not combine metadata and data from different clipboard generations.
        guard pasteboard.changeCount == observedCount else { return }
        item.sourceApp = app?.localizedName
        item.sourceBundle = app?.bundleIdentifier
        receive?(item)
    }
}
