import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var preferences = Preferences.load() {
        didSet {
            preferences.save()
            if oldValue.aiEnabled && !preferences.aiEnabled { ai.reset() }
            if oldValue.persistence && !preferences.persistence { storageReadable = true }
            history.enforceLimit(preferences.historyLimit)
            _ = history.enforceStorage(imageLimit: preferences.imageLimitMB * 1024 * 1024)
            persist()
            preferencesChanged?(oldValue)
        }
    }
    @Published var history = History()
    @Published var focusSearch = UUID()
    @Published var message = ""
    @Published var tab = "History"
    @Published var selectedID: UUID?
    @Published var hotkeyError = ""
    let monitor = ClipboardMonitor()
    let ai = AIViewModel()
    private let persistence = HistoryPersistence.standard
    private let diskQueue = DispatchQueue(label: "com.usamam46.ClipBro.storage", qos: .utility)
    private var storageReadable = true
    var dismiss: () -> Void = {}
    @Published var settingsTab = "General"
    var showLauncher: () -> Void = {}
    var openSettings: () -> Void = {}
    var paste: () -> Void = {}
    var preferencesChanged: ((Preferences) -> Void)?
    init() {
        if ProcessInfo.processInfo.arguments.contains("--ui-smoke-test") { return }
        tab = preferences.defaultTab
        if preferences.persistence {
            do { history = try persistence.load(); history.enforceLimit(preferences.historyLimit); _ = history.enforceStorage(imageLimit: preferences.imageLimitMB * 1024 * 1024) }
            catch { storageReadable = false; message = "History could not be read. The existing file has been preserved. Clear all history to reset." }
        }
        monitor.preferences = { [weak self] in self?.preferences ?? Preferences() }
        monitor.receive = { [weak self] in self?.add($0) }
    }
    func add(_ item: ClipItem) {
        let before = history
        history.insert(item, limit: preferences.historyLimit)
        if !history.enforceStorage(imageLimit: preferences.imageLimitMB * 1024 * 1024) {
            history = before
            message = "Storage cap reached by pinned clips. Remove some clips to capture more."
            return
        }
        if !history.items.contains(where: { $0.fingerprint == item.fingerprint }) {
            message = "Clip exceeds your storage limit."
        }
        if selectedID == nil { selectedID = item.id }
        persist()
    }
    func persist() {
        guard !ProcessInfo.processInfo.arguments.contains("--ui-smoke-test") else { return }
        guard storageReadable else { return }
        let snapshot = history
        let enabled = preferences.persistence
        let storage = persistence
        diskQueue.async { [weak self] in
            do { if enabled { try storage.save(snapshot) } else { try storage.clear() } }
            catch { Task { @MainActor in self?.message = "Unable to save history. Check available storage and permissions." } }
        }
    }
    func flush() { diskQueue.sync {} }
    func pin(_ item: ClipItem) {
        if !history.setPinned(item.id, pinned: !item.pinned, pinLimit: preferences.pinLimit, historyLimit: preferences.historyLimit) {
            message = "Pin limit reached. Increase it in Settings."
        }
        persist()
    }
    func delete(_ item: ClipItem) { history.items.removeAll { $0.id == item.id }; MediaService.purgeThumbnails(); persist() }
    func clear(all: Bool) {
        if all { history.items.removeAll(); storageReadable = true } else { history.items.removeAll { !$0.pinned } }
        selectedID = nil; MediaService.purgeThumbnails(); ai.reset(); persist()
    }
    func title(_ id: UUID, value: String) {
        guard let index = history.items.firstIndex(where: { $0.id == id }) else { return }
        history.items[index].title = String(value.prefix(200)); persist()
    }
    func copy(_ item: ClipItem, plain: Bool = false, activate: Bool = false) {
        let board = NSPasteboard.general
        var success = false
        if item.kind == .file && !plain, let paths = item.fileURLs {
            let urls = paths.compactMap(URL.init(string:))
            guard !urls.isEmpty, urls.allSatisfy({ FileManager.default.isReadableFile(atPath: $0.path) }) else {
                message = "A referenced file is missing or inaccessible. Copy as plain text to copy its path."; return
            }
            board.clearContents()
            success = board.writeObjects(urls as [NSURL])
        } else if item.kind == .image, let data = item.imageData, let type = item.imageType {
            guard !plain else { message = "Use Extract Text on this image first."; return }
            board.clearContents()
            success = board.setData(data, forType: NSPasteboard.PasteboardType(type))
        } else {
            board.clearContents()
            success = board.setString(item.text, forType: .string)
            if !plain, let rtf = item.richText { _ = board.setData(rtf, forType: .rtf) }
        }
        guard success else { message = "Clipboard write failed."; return }
        monitor.ignoreCurrent()
        var recent = item; recent.lastCopiedAt = Date()
        history.insert(recent, limit: preferences.historyLimit); persist()
        message = "Copied to clipboard"
        if activate && preferences.pasteOnActivate { paste() }
    }
    func replacePreservingOriginal(_ id: UUID, text: String) {
        guard let index = history.items.firstIndex(where: { $0.id == id }) else { message = "Original clip is no longer available."; return }
        if !history.items[index].pinned {
            guard history.setPinned(id, pinned: true, pinLimit: preferences.pinLimit, historyLimit: preferences.historyLimit) else {
                message = "Free a pin slot to preserve the original, or save the result as a new clip."; return
            }
        }
        add(ClipItem(text: text, kind: Classifier.classify(text), generated: true))
        message = "Result saved; the original is pinned for recovery."
    }
    func activate(_ item: ClipItem, plain: Bool = false) { copy(item, plain: plain, activate: true) }
}
