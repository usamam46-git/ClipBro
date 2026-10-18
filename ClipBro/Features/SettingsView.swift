import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState
    var body: some View {
        Form {
            Section("General") {
                Toggle("Open panel on launch", isOn: $state.preferences.showOnLaunch)
            }
            Section("Clipboard") {
                Toggle("Monitor clipboard", isOn: $state.preferences.monitoring)
                Toggle("Keep history across restarts", isOn: $state.preferences.persistence)
                Stepper("Recent items: \(state.preferences.historyLimit)", value: $state.preferences.historyLimit, in: 1...200)
                Toggle("Skip likely secrets", isOn: $state.preferences.skipSensitive)
            }
            Text("ClipBro keeps your clipboard on this Mac. No text is sent externally without an explicit AI action.").font(.caption).foregroundStyle(.secondary)
        }.formStyle(.grouped).padding().frame(width: 620, height: 620)
    }
}
