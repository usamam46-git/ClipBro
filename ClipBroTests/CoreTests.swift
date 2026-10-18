import Foundation

@main struct CoreTests {
    static var count = 0
    static func check(_ condition: @autoclosure () -> Bool, _ label: String) {
        guard condition() else { fatalError("FAIL: \(label)") }
        count += 1
        print("PASS: \(label)")
    }
    static func main() throws {
        var history = History()
        for n in 1...21 { history.insert(ClipItem(text: "fixture \(n)", kind: .text), limit: 20) }
        check(history.items.count == 20 && !history.items.contains { $0.text == "fixture 1" }, "21st item evicts oldest")
        let pinnedID = history.items.last!.id
        check(history.setPinned(pinnedID, pinned: true, pinLimit: 2, historyLimit: 20), "pin accepted")
        for n in 22...45 { history.insert(ClipItem(text: "fixture \(n)", kind: .text), limit: 20) }
        check(history.items.count == 21 && history.items.contains { $0.id == pinnedID }, "pin survives rolling eviction")
        let duplicateID = history.items[2].id
        history.insert(history.items[2], limit: 20)
        check(history.items.first?.id == duplicateID && history.items.count == 21, "duplicate preserves identity and moves to front")
        check(history.setPinned(pinnedID, pinned: false, pinLimit: 2, historyLimit: 20) && history.items.first?.id == pinnedID, "unpin retains item")
        let unicode = "👩🏽‍💻 👨‍👩‍👧‍👦 🇵🇰 café\nمرحبا"
        history.insert(ClipItem(text: unicode, kind: .text), limit: 20)
        check(history.items.first?.text == unicode, "Unicode roundtrip")
        check(ClipItem(text: "café", kind: .text).fingerprint == ClipItem(text: "cafe\u{301}", kind: .text).fingerprint, "canonical normalization")
        check(ClipItem(text: " x", kind: .text).fingerprint != ClipItem(text: "x", kind: .text).fingerprint, "meaningful whitespace retained")
        let titled = ClipItem(text: "hello\nWORLD", kind: .text, title: "Client draft")
        check(titled.matches("world CLIENT") && !titled.matches("missing"), "case insensitive title and multiline search")
        for (text, kind) in [("https://example.com/a", ClipKind.url), ("dev@example.com", .email), ("+1 (555) 123-4567", .phone), (#"{"x":1}"#, .json), ("SELECT * FROM users", .sql), ("func sample() {}", .code), (String(repeating: "a", count: 501), .note), ("hello", .text)] {
            check(Classifier.classify(text) == kind, "classification \(kind.rawValue)")
        }
        check(PrivacyFilter.shouldIgnore(types: ["org.nspasteboard.ConcealedType"]), "concealed clipboard excluded")
        check(PrivacyFilter.likelySecret("password=synthetic-fixture"), "sensitive assignment detected")
        check(!PrivacyFilter.likelySecret("hello world"), "ordinary text accepted")
        var gate = ClipboardGate(changeCount: 10)
        check(!gate.changed(10) && gate.changed(11) && !gate.changed(11), "change count gate")
        gate.ignore(12)
        check(!gate.changed(12) && gate.changed(13), "internal writes suppressed")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = HistoryPersistence(directory: directory)
        try persistence.save(history)
        let restored = try persistence.load()
        check(restored.items == history.items, "atomic persistence roundtrip")
        history.items.removeAll { $0.id == pinnedID }
        try persistence.save(history)
        let afterDeletion = try persistence.load()
        check(!afterDeletion.items.contains { $0.id == pinnedID }, "deletion persisted")
        try persistence.clear()
        check(!FileManager.default.fileExists(atPath: persistence.file.path), "clear removes persisted content")
        let suite = "ClipBroTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var prefs = Preferences()
        prefs.historyLimit = 31
        prefs.save(to: defaults)
        check(Preferences.load(from: defaults).historyLimit == 31, "configuration persistence")
        check(Set(Emoji.all.map(\.symbol)).count == Emoji.all.count, "emoji identifiers unique")
        check(Emoji.all.contains { $0.symbol == "👩🏽‍💻" && $0.matches("developer") == false && $0.matches("technologist") }, "multicodepoint emoji searchable")
        var mediaHistory = History()
        let media = ClipItem(text: "Synthetic image fixture", kind: .image, imageData: Data(repeating: 7, count: 100))
        mediaHistory.insert(media, limit: 20)
        check(mediaHistory.enforceStorage(imageLimit: 50) && mediaHistory.items.isEmpty, "image storage cap eviction")
        var pinMedia = media; pinMedia.pinned = true
        mediaHistory.insert(pinMedia, limit: 20)
        check(!mediaHistory.enforceStorage(imageLimit: 50) && mediaHistory.items.count == 1, "storage cap preserves pins")
        var rich = ClipItem(text: "rich fixture", kind: .text)
        rich.richText = Data("{synthetic}".utf8)
        rich.fileURLs = ["file:///tmp/fixture"]
        mediaHistory.insert(rich, limit: 20)
        try persistence.save(mediaHistory)
        let mediaRestored = try persistence.load()
        check(mediaRestored.items == mediaHistory.items, "rich binary and file reference persistence")
        check(!MediaService.validImage(Data("invalid".utf8)), "invalid image rejected")
        print("\(count) checks passed")
    }
}
