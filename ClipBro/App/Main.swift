import AppKit
import SwiftUI

@main
struct ClipBroApp {
    static func main() {
        let app = NSApplication.shared
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
    private var previousApplication: NSRunningApplication?
    let state = AppState()
    private let hotkey = HotkeyService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        state.openSettings = { [weak self] in self?.showSettings() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "clipboard.fill", accessibilityDescription: "ClipBro")
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
        state.monitor.start()
        if state.preferences.showOnLaunch { showPanel() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.monitor.stop(); state.flush(); hotkey.stop()
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
    @objc func showSettings() {
        hidePanel()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 620), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
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
