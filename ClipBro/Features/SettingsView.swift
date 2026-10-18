import SwiftUI
import ServiceManagement
import Carbon

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var clearAll = false
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginError = ""
    var body: some View {
        TabView {
            general.tabItem { Label("General", systemImage: "gearshape") }
            clipboard.tabItem { Label("Clipboard", systemImage: "clipboard") }
            shortcuts.tabItem { Label("Shortcuts", systemImage: "keyboard") }
            AISettingsView(state: state).tabItem { Label("AI", systemImage: "sparkles") }
            privacy.tabItem { Label("Privacy", systemImage: "hand.raised") }
        }.padding().frame(width: 620, height: 620).tint(Design.gold)
        .preferredColorScheme(state.preferences.theme == "Dark" ? .dark : state.preferences.theme == "Light" ? .light : nil)
        .confirmationDialog("Permanently clear all history, including pinned items?", isPresented: $clearAll) {
            Button("Clear All", role: .destructive) { state.clear(all: true) }
        }
    }
    private var general: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $loginEnabled).onChange(of: loginEnabled) {
                    do {
                        if loginEnabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginError = SMAppService.mainApp.status == .requiresApproval ? "Approve ClipBro in System Settings → General → Login Items." : ""
                    } catch { loginError = "Login item change failed. Install ClipBro in Applications first." }
                }
                if !loginError.isEmpty { Text(loginError).foregroundStyle(.secondary) }
                Toggle("Open panel on launch", isOn: $state.preferences.showOnLaunch)
                Picker("Default tab", selection: $state.preferences.defaultTab) { Text("History").tag("History"); Text("Emoji").tag("Emoji") }
            }
            Section("Appearance") {
                Toggle("Subtle hover animations", isOn: $state.preferences.animations)
                Picker("Theme", selection: $state.preferences.theme) { ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) } }
                Text("The menu-bar icon stays visible so Settings and Quit are always reachable.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
    private var clipboard: some View {
        Form {
            Section("History") {
                Toggle("Monitor clipboard", isOn: $state.preferences.monitoring)
                Toggle("Keep history across restarts", isOn: $state.preferences.persistence)
                Stepper("Recent items: \(state.preferences.historyLimit)", value: $state.preferences.historyLimit, in: 1...200)
                Stepper("Image storage: \(state.preferences.imageLimitMB) MB", value: $state.preferences.imageLimitMB, in: 1...50)
                Stepper("Pinned items: \(state.preferences.pinLimit)", value: $state.preferences.pinLimit, in: 1...200)
                Text("Duplicates move to the top while keeping their title and pin. Existing pins are retained if the pin limit is lowered.").font(.caption).foregroundStyle(.secondary)
                Button("Clear recent items") { state.clear(all: false) }
                Button("Clear all history…", role: .destructive) { clearAll = true }
            }
        }.formStyle(.grouped)
    }
    private var shortcuts: some View {
        Form {
            Section("Global launcher") {
                Picker("Key", selection: $state.preferences.hotkeyCode) {
                    Text("V").tag(UInt32(9)); Text("B").tag(UInt32(11)); Text("Space").tag(UInt32(49)); Text("J").tag(UInt32(38))
                }
                Picker("Modifiers", selection: $state.preferences.hotkeyModifiers) {
                    Text("Command + Shift").tag(UInt32(cmdKey | shiftKey))
                    Text("Command + Option").tag(UInt32(cmdKey | optionKey))
                    Text("Control + Option").tag(UInt32(controlKey | optionKey))
                }
                if !state.hotkeyError.isEmpty { Text(state.hotkeyError).foregroundStyle(.red) }
                Text("Default: ⌘⇧V. Conflicts are reported by macOS; app-local shortcuts may still compete.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Activation") {
                Toggle("Paste into the previous app on Enter / double-click", isOn: $state.preferences.pasteOnActivate)
                Text("Copy-only is the default. ⌘C and row copy buttons always copy without pasting. Automatic paste needs Accessibility permission; some apps reject synthetic input.").font(.caption).foregroundStyle(.secondary)
                Button("Enable Accessibility for automatic paste…") { PasteService.requestPermission() }
            }
        }.formStyle(.grouped)
    }
    private var privacy: some View {
        Form {
            Section("Capture controls") {
                Toggle("Skip likely secrets", isOn: $state.preferences.skipSensitive)
                Text("Heuristics can miss passwords and may exclude harmless text. Concealed and transient clipboard markers are always respected. Pause capture when handling secrets.").font(.caption).foregroundStyle(.secondary)
                TextField("Excluded bundle IDs, comma separated", text: $state.preferences.excludedApps, axis: .vertical).lineLimit(3...5)
                Text("Source app is inferred from the foreground app, not guaranteed pasteboard ownership.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Local storage") {
                Text(HistoryPersistence.standard.directory.path).font(.caption).textSelection(.enabled)
                Text("History is stored locally with owner-only file permissions, not application-level encryption. Turning persistence off removes saved history. No automatic network requests are made.").font(.caption).foregroundStyle(.secondary)
                Button("Clear all history…", role: .destructive) { clearAll = true }
            }
        }.formStyle(.grouped)
    }
}
