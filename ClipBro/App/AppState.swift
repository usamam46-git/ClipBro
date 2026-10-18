import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var preferences = Preferences.load() {
        didSet {
            preferences.save()
            history.enforceLimit(preferences.historyLimit)
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
    var openSettings: () -> Void = {}
    var paste: () -> Void = {}
    var preferencesChanged: ((Preferences) -> Void)?
    init() {
        tab = preferences.defaultTab
        if preferences.persistence {
            do { history = try persistence.load(); history.enforceLimit(preferences.historyLimit) }
            catch { storageReadable = false; message = "History could not be read. The existing file has been preserved. Clear all history to reset." }
        }
        monitor.preferences = { [weak self] in self?.preferences ?? Preferences() }
        monitor.receive = { [weak self] in self?.add($0) }
    }
    func add(_ item: ClipItem) {
        history.insert(item, limit: preferences.historyLimit)
        if selectedID == nil { selectedID = item.id }
        persist()
    }
    func persist() {
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
    func delete(_ item: ClipItem) { history.items.removeAll { $0.id == item.id }; persist() }
    func clear(all: Bool) {
        if all { history.items.removeAll(); storageReadable = true } else { history.items.removeAll { !$0.pinned } }
        selectedID = nil; persist()
    }
    func title(_ id: UUID, value: String) {
        guard let index = history.items.firstIndex(where: { $0.id == id }) else { return }
        history.items[index].title = String(value.prefix(200)); persist()
    }
    func copy(_ item: ClipItem, plain: Bool = false, activate: Bool = false) {
        let board = NSPasteboard.general
        board.clearContents()
        guard board.setString(item.text, forType: .string) else { message = "Clipboard write failed."; return }
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
