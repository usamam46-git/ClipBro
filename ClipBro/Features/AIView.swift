import SwiftUI

@MainActor
final class AIViewModel: ObservableObject {
    @Published var input = ""
    @Published var output = ""
    @Published var action = AIAction.all[0].name
    @Published var working = false
    @Published var error = ""
    @Published var sourceID: UUID?
    @Published var resultAction = ""
    private var task: Task<Void, Never>?
    func run(preferences: Preferences) {
        cancel()
        error = ""; output = ""; working = true
        let text = input
        let choice = AIAction.all.first { $0.name == action } ?? AIAction.all[0]
        task = Task {
            do {
                guard preferences.aiEnabled else { throw AIError.disabled }
                let key = try KeychainService.read()
                let result = try await AIService().transform(text: text, action: choice, preferences: preferences, key: key)
                try Task.checkCancellation()
                output = result; resultAction = choice.name; working = false
            } catch is CancellationError { }
            catch {
                guard !Task.isCancelled else { return }
                self.error = (error as? LocalizedError)?.errorDescription ?? "Network request failed. Check your connection and retry."
                working = false
            }
        }
    }
    func cancel() { task?.cancel(); task = nil; working = false }
    func reset() { cancel(); input = ""; output = ""; error = ""; sourceID = nil }
}
struct AIView: View {
    @ObservedObject var state: AppState
    @ObservedObject var model: AIViewModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !state.preferences.aiEnabled {
                    Label("AI is off · your clipboard stays local", systemImage: "lock.shield").font(.headline)
                    Button("Configure AI in Settings", action: state.openSettings)
                }
                HStack {
                    Text("TEXT TO SUBMIT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Use selected clip") { loadSelected() }.disabled(model.working)
                }
                TextEditor(text: $model.input).font(.system(size: 12)).frame(height: 105).disabled(model.working)
                Text("Only this text is sent to OpenAI when you click Send. Review it for private information. API usage may incur charges.")
                    .font(.caption).foregroundStyle(.secondary)
                if PrivacyFilter.likelySecret(model.input) { Label("This text may contain a secret. Review it before sending.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange).font(.caption) }
                Picker("Action", selection: $model.action) { ForEach(AIAction.all) { Text($0.name).tag($0.name) } }.disabled(model.working)
                HStack {
                    Button(model.error.isEmpty ? "Send to OpenAI" : "Retry request") { model.run(preferences: state.preferences) }
                        .buttonStyle(.borderedProminent).disabled(!state.preferences.aiEnabled || model.input.isEmpty || model.working || model.input.count > 24_000)
                    if model.working { ProgressView().controlSize(.small); Button("Cancel") { model.cancel() } }
                    Spacer()
                    Text("\(model.input.count) / 24,000").font(.caption2).foregroundStyle(.secondary)
                }
                if !model.error.isEmpty { Text(model.error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
                if !model.output.isEmpty {
                    Divider()
                    Text("RESULT · \(model.resultAction)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Text(model.output).font(.system(size: 12)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        Button("Copy") { state.copy(ClipItem(text: model.output, kind: Classifier.classify(model.output), generated: true)) }
                        Button("Save as new") { save() }
                        if model.resultAction == "Generate title" {
                            Button("Apply title") { if let id = model.sourceID { state.title(id, value: model.output) } }
                                .disabled(model.sourceID == nil)
                        } else {
                            Button("Replace clip") {
                                if let id = model.sourceID { state.replacePreservingOriginal(id, text: model.output) }
                            }.disabled(model.sourceID == nil)
                        }
                        Button("Discard") { model.output = "" }
                    }.controlSize(.small)
                    Text("Replace pins the original for recovery; it requires an available pin slot.").font(.caption2).foregroundStyle(.secondary)
                }
            }.padding(2)
        }.onAppear { if model.input.isEmpty { loadSelected() } }
        .onChange(of: state.preferences.aiEnabled) { if !state.preferences.aiEnabled { model.reset() } }
    }
    private func loadSelected() {
        guard let item = state.history.items.first(where: { $0.id == state.selectedID }) ?? state.history.ordered.first, item.kind != .image else { return }
        model.input = item.text; model.sourceID = item.id; model.output = ""
    }
    private func save() {
        state.add(ClipItem(text: model.output, kind: Classifier.classify(model.output), generated: true))
        state.message = "Saved AI result as a new clip."
    }
}
struct AISettingsView: View {
    @ObservedObject var state: AppState
    @State private var key = ""
    @State private var status = ""
    var body: some View {
        Form {
            Section("Optional cloud processing") {
                Toggle("Enable OpenAI actions", isOn: $state.preferences.aiEnabled)
                Text("No automatic requests. Each Send action submits the previewed text to OpenAI. Your API account is billed separately. Requests use store: false; provider retention policies still apply.").font(.caption).foregroundStyle(.secondary)
                SecureField("OpenAI API key", text: $key)
                HStack {
                    Button("Save key in Keychain") {
                        do { try KeychainService.save(key); key = ""; status = "Key saved in Keychain." }
                        catch { status = error.localizedDescription }
                    }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Remove key", role: .destructive) {
                        do { try KeychainService.delete(); key = ""; status = "Key removed." }
                        catch { status = error.localizedDescription }
                    }
                }
                if !status.isEmpty { Text(status).font(.caption) }
                TextField("Model", text: $state.preferences.model)
                Text("Default: gpt-4.1-mini. Model access depends on your API account.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Custom transformation") {
                TextEditor(text: $state.preferences.customPrompt).frame(height: 80)
                Text("Only the first 2,000 characters of this instruction are used.").font(.caption).foregroundStyle(.secondary)
            }
            Button("Clear saved AI results", role: .destructive) {
                state.history.items.removeAll { $0.generated }; state.ai.reset(); state.persist()
            }
        }.formStyle(.grouped)
    }
}
