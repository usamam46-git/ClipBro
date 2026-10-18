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
        guard gate.changed(pasteboard.changeCount) else { return }
        let prefs = preferences()
        guard prefs.monitoring, !PrivacyFilter.shouldIgnore(types: pasteboard.typeNames) else { return }
        let app = NSWorkspace.shared.frontmostApplication
        let excluded = prefs.excludedApps.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !excluded.contains(app?.bundleIdentifier ?? "") else { return }
        guard let text = pasteboard.readText(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 1_000_000 else { return }
        guard !prefs.skipSensitive || !PrivacyFilter.likelySecret(text) else { return }
        var item = ClipItem(text: text, kind: Classifier.classify(text))
        item.sourceApp = app?.localizedName
        item.sourceBundle = app?.bundleIdentifier
        receive?(item)
    }
}
