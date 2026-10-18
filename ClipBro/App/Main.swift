import AppKit
import SwiftUI

@main
struct ClipBroApp {
    static func main() {
        let app = NSApplication.shared
        if ProcessInfo.processInfo.arguments.contains("--light") { app.appearance = NSAppearance(named: .aqua) }
        if ProcessInfo.processInfo.arguments.contains("--dark") { app.appearance = NSAppearance(named: .darkAqua) }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var panel: LauncherPanel!
    private var settingsWindow: NSWindow?
    private var outsideMonitor: Any?
    private var keyboardMonitor: Any?
    private var previousApplication: NSRunningApplication?
    let state = AppState()
    private let hotkey = HotkeyService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        state.showLauncher = { [weak self] in self?.settingsWindow?.orderOut(nil); self?.showPanel() }
        state.openSettings = { [weak self] in self?.showSettings() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = MenuBarIcon.make()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        panel = LauncherPanel(contentRect: NSRect(x: 0, y: 0, width: Design.panelWidth, height: Design.panelHeight), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: LauncherView(state: state))
        panel.onEscape = { [weak self] in self?.hidePanel() }
        state.dismiss = { [weak self] in self?.hidePanel() }
        state.paste = { [weak self] in
            guard let self else { return }
            let destination = self.previousApplication
            self.hidePanel()
            Task { @MainActor in
                if let message = await PasteService.paste(to: destination) {
                    self.state.message = message
                    self.showPanel()
                }
            }
        }
        hotkey.action = { [weak self] in self?.togglePanel() }
        registerHotkey()
        state.preferencesChanged = { [weak self] old in
            guard let self else { return }
            if old.hotkeyCode != self.state.preferences.hotkeyCode || old.hotkeyModifiers != self.state.preferences.hotkeyModifiers { self.registerHotkey() }
        }
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow, self.panel.attachedSheet == nil else { return event }
            if event.keyCode == 53 { self.hidePanel(); return nil }
            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            if modifiers == .command && event.charactersIgnoringModifiers == "f" {
                self.state.focusSearch = UUID(); return nil
            }
            if self.state.tab == "AI" { return event }
            if modifiers == .command && event.charactersIgnoringModifiers == "c" {
                if let editor = self.panel.firstResponder as? NSTextView, editor.selectedRange().length > 0 { return event }
                NotificationCenter.default.post(name: .copySelectedClip, object: nil); return nil
            }
            guard modifiers.isEmpty else { return event }
            if event.keyCode == 36 || event.keyCode == 76 {
                NotificationCenter.default.post(name: self.state.tab == "Emoji" ? .emojiActivate : .activateSelectedClip, object: nil); return nil
            }
            if event.keyCode == 125 || event.keyCode == 126 {
                let delta = event.keyCode == 125 ? 1 : -1
                NotificationCenter.default.post(name: self.state.tab == "Emoji" ? .emojiMove : .historyMove, object: self.state.tab == "Emoji" ? delta * 8 : delta); return nil
            }
            if self.state.tab == "Emoji" && (event.keyCode == 123 || event.keyCode == 124) {
                NotificationCenter.default.post(name: .emojiMove, object: event.keyCode == 124 ? 1 : -1); return nil
            }
            return event
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-smoke-test") {
            state.history.items = [
                ClipItem(text: "SELECT name, created_at FROM projects ORDER BY created_at DESC;", kind: .sql, pinned: true, title: "Project activity query"),
                ClipItem(text: "Thanks for the feedback. I’ll send the revised draft tomorrow.", kind: .text, title: "Client follow-up draft"),
                ClipItem(text: "https://developer.apple.com/documentation/appkit", kind: .url),
                ClipItem(text: "func greet() { print(\"Hello\") }", kind: .code),
                ClipItem(text: "👩🏽‍💻 A good day to build something useful.", kind: .text)
            ]
            state.selectedID = state.history.items.first?.id
            if ProcessInfo.processInfo.arguments.contains("--emoji") { state.tab = "Emoji" }
            if ProcessInfo.processInfo.arguments.contains("--ai") { state.tab = "AI" }
            showPanel()
            if ProcessInfo.processInfo.arguments.contains("--settings") { state.settingsTab = "Shortcuts"; showSettings() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.function, .numericPad], timestamp: 0, windowNumber: self.panel.windowNumber, context: nil, characters: "\u{F701}", charactersIgnoringModifiers: "\u{F701}", isARepeat: false, keyCode: 125) {
                    NSApp.postEvent(event, atStart: false)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.finishSmokeTest() }
            return
        }
        state.monitor.start()
        if !UserDefaults.standard.bool(forKey: "welcomeShown") {
            state.settingsTab = "Shortcuts"
            showSettings()
            UserDefaults.standard.set(true, forKey: "welcomeShown")
        } else if state.preferences.showOnLaunch { showPanel() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let settingsWindow, settingsWindow.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
        } else if panel != nil { showPanel() }
        return false
    }

    private func finishSmokeTest() {
        let renderedWindow: NSWindow = ProcessInfo.processInfo.arguments.contains("--settings") ? (settingsWindow ?? panel) : panel
        guard let view = renderedWindow.contentView else { NSApp.terminate(nil); return }
        view.layoutSubtreeIfNeeded()
        if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            if let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/ui-preview.png"))
            }
        }
        let navigated = state.selectedID == state.history.items.dropFirst().first?.id
        let report = "settingsVisible=\(settingsWindow?.isVisible ?? false)\narrowNavigated=\(navigated)\npanelVisible=\(panel.isVisible)\npanelKey=\(panel.isKeyWindow)\naccessibilityTrusted=\(PasteService.permitted)\nhotkeyError=\(state.hotkeyError)\n"
        try? report.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/ui-smoke.txt"), atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }
    func applicationWillTerminate(_ notification: Notification) {
        state.monitor.stop(); state.flush(); hotkey.stop()
        if let keyboardMonitor { NSEvent.removeMonitor(keyboardMonitor) }
    }
    private func registerHotkey() {
        state.hotkeyError = hotkey.register(code: state.preferences.hotkeyCode, modifiers: state.preferences.hotkeyModifiers) ? "" : "Shortcut unavailable. The previous shortcut remains active; choose another."
    }
    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu() }
        else { togglePanel() }
    }
    func togglePanel() { panel.isVisible ? hidePanel() : showPanel() }
    func showPanel() {
        if panel.isVisible { return }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication = NSWorkspace.shared.frontmostApplication
        }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let rect = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: rect.midX - panel.frame.width / 2, y: max(rect.minY, rect.midY - panel.frame.height / 2)))
        }
        panel.makeKeyAndOrderFront(nil)
        state.focusSearch = UUID()
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hidePanel() }
        }
    }
    func hidePanel() {
        panel.orderOut(nil)
        if let monitor = outsideMonitor { NSEvent.removeMonitor(monitor); outsideMonitor = nil }
    }
    func windowDidResignKey(_ notification: Notification) {
        if notification.object as? NSWindow === panel, panel.attachedSheet == nil { hidePanel() }
    }
    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open ClipBro", action: #selector(openPanel), keyEquivalent: "")
        menu.addItem(withTitle: "Set Up Automatic Paste…", action: #selector(showPasteSetup), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(withTitle: state.preferences.monitoring ? "Pause Monitoring" : "Resume Monitoring", action: #selector(toggleMonitoring), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ClipBro", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    @objc private func openPanel() { showPanel() }
    @objc private func toggleMonitoring() { state.preferences.monitoring.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func showPasteSetup() { state.settingsTab = "Shortcuts"; showSettings() }
    @objc func showSettings() {
        hidePanel()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 680), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "ClipBro Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(state: state))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

final class LauncherPanel: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}
