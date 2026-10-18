import AppKit
import ApplicationServices

@MainActor
final class PasteService {
    static var permitted: Bool { AXIsProcessTrusted() }
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    static func paste(to destination: NSRunningApplication?) async -> String? {
        guard permitted else { return "Copied. Enable Accessibility in Settings to paste automatically." }
        guard let destination, !destination.isTerminated,
              destination.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return "Copied. Return to your app and press ⌘V."
        }
        guard destination.activate(options: []) else { return "Copied. Could not activate the destination app." }
        // Wait for activation, and never send the key to an unrelated foreground app.
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 40_000_000)
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == destination.processIdentifier {
                guard let source = CGEventSource(stateID: .combinedSessionState),
                      let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                      let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
                    return "Copied. Keyboard event creation failed."
                }
                down.flags = .maskCommand; up.flags = .maskCommand
                down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
                return nil
            }
        }
        return "Copied. Destination did not gain focus; use ⌘V manually."
    }
}
