import AppKit
import CoreText

@main struct ClipboardIntegrationTests {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let board = NSPasteboard(name: .init("ClipBro.Tests.\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        let monitor = ClipboardMonitor(pasteboard: board)
        var prefs = Preferences()
        prefs.excludedApps = ""
        monitor.preferences = { prefs }
        var history = History()
        monitor.receive = { history.insert($0, limit: 20) }
        var count = 0
        func check(_ value: Bool, _ name: String) { precondition(value, name); count += 1; print("PASS: \(name)") }
        for index in 1...21 {
            board.clearContents(); board.setString("integration fixture \(index)", forType: .string); monitor.poll()
        }
        check(history.items.count == 20 && history.items.last?.text == "integration fixture 2", "actual named pasteboard 21-item capture")
        monitor.poll()
        check(history.items.count == 20, "unchanged named pasteboard ignored")
        prefs.monitoring = false
        board.clearContents(); board.setString("paused fixture", forType: .string); monitor.poll()
        check(!history.items.contains { $0.text == "paused fixture" }, "pause stops capture")
        prefs.monitoring = true; monitor.poll()
        check(!history.items.contains { $0.text == "paused fixture" }, "resume does not capture paused generation")
        board.clearContents(); board.setString("concealed fixture", forType: .string)
        board.setData(Data(), forType: .init("org.nspasteboard.ConcealedType")); monitor.poll()
        check(!history.items.contains { $0.text == "concealed fixture" }, "concealed marker respected on pasteboard")
        board.clearContents(); board.setString("password=synthetic-only", forType: .string); monitor.poll()
        check(!history.items.contains { $0.text.contains("password=") }, "secret heuristic enforced on capture")
        board.clearContents(); board.setString("internal fixture", forType: .string); monitor.ignoreCurrent(); monitor.poll()
        check(!history.items.contains { $0.text == "internal fixture" }, "internal write suppressed on pasteboard")
        let emoji = "👩🏽‍💻🇵🇰👨‍👩‍👧‍👦"
        board.clearContents(); board.setString(emoji, forType: .string); monitor.poll()
        check(history.items.first?.text == emoji, "multi-codepoint clipboard capture")
        let rich = NSAttributedString(string: "Rich synthetic fixture", attributes: [.font: NSFont.boldSystemFont(ofSize: 16)])
        let rtf = try rich.data(from: NSRange(location: 0, length: rich.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        board.clearContents(); board.setData(rtf, forType: .rtf); monitor.poll()
        check(history.items.first?.text == rich.string && history.items.first?.richText == rtf, "RTF-only extraction and preservation")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClipBro-fixture-\(UUID().uuidString).txt")
        try Data("synthetic".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        board.clearContents(); board.writeObjects([url as NSURL]); monitor.poll()
        check(history.items.first?.kind == .file && history.items.first?.fileURLs == [url.absoluteString], "file reference capture")
        let width = 1000, height = 220
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "CLIPBRO TEST 123", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 64, nil), NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)]))
        context.textPosition = CGPoint(x: 40, y: 90); CTLineDraw(line, context)
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
        let image = rep.representation(using: .png, properties: [:])!
        board.clearContents(); board.setData(image, forType: .png); monitor.poll()
        check(history.items.first?.imageData == image && history.items.first?.kind == .image, "PNG bytes preserved")
        let recognized = try await MediaService.extractText(image)
        check(recognized.contains("CLIPBRO") && recognized.contains("123"), "Vision OCR on synthetic image")
        print("\(count) integration checks passed; system clipboard untouched")
    }
}
