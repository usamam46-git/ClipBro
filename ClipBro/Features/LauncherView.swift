import SwiftUI

struct LauncherView: View {
    @ObservedObject var state: AppState
    @State private var search = ""
    @State private var detail: ClipItem?
    @State private var clearAll = false
    @FocusState private var searchFocused: Bool
    var results: [ClipItem] { state.history.ordered.filter { $0.matches(search) } }
    var selected: ClipItem? { results.first { $0.id == state.selectedID } ?? results.first }
    var body: some View {
        VStack(spacing: Design.spacing) {
            header
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search clips, emojis, snippets…", text: $search)
                    .textFieldStyle(.plain).focused($searchFocused)
                    .onSubmit { if state.tab == "Emoji" { NotificationCenter.default.post(name: .emojiActivate, object: nil) } else if state.tab == "History", let selected { state.activate(selected) } }
                if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) }
            }.padding(12).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Design.rowRadius))
            Picker("View", selection: $state.tab) {
                Text("History").tag("History")
                Text("Emoji").tag("Emoji")
                Text("AI").tag("AI")
            }.pickerStyle(.segmented)
            if state.tab == "Emoji" { EmojiPicker(state: state, search: search) } else if state.tab == "AI" { AIView(state: state, model: state.ai) } else { historyView }
            if !state.message.isEmpty {
                HStack {
                    Text(state.message).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { state.message = "" } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }
            }
            Divider()
            HStack {
                Text("↑↓ Navigate    ↵ \(state.preferences.pasteOnActivate ? "Paste" : "Copy")    ⌘C Copy")
                Spacer()
                Text(state.preferences.monitoring ? "LOCAL FIRST" : "PAUSED").tracking(1)
            }.font(.caption2).foregroundStyle(.secondary)
        }.padding(Design.inset)
        .frame(width: Design.panelWidth, height: Design.panelHeight)
        .background(GlassBackground())
        .clipShape(RoundedRectangle(cornerRadius: Design.radius))
        .overlay(RoundedRectangle(cornerRadius: Design.radius).strokeBorder(.primary.opacity(0.08)))
        .tint(Design.gold)
        .preferredColorScheme(state.preferences.theme == "Dark" ? .dark : state.preferences.theme == "Light" ? .light : nil)
        .onChange(of: state.focusSearch) { searchFocused = true }
        .onChange(of: search) { state.selectedID = results.first?.id }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .background {
            Group {
                Button("Find") { searchFocused = true }.keyboardShortcut("f")
                Button("Copy selected") { if let selected { state.copy(selected) } }.keyboardShortcut("c")
            }.hidden()
        }
        .sheet(item: $detail) { item in ItemDetailView(state: state, item: item) }
        .confirmationDialog("Clear all clipboard history, including pinned items?", isPresented: $clearAll) {
            Button("Clear All", role: .destructive) { state.clear(all: true) }
        }
    }
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "clipboard.fill").font(.title2).foregroundStyle(Design.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("ClipBro").font(.title2.weight(.semibold))
                Text("Keep the good bits.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { state.preferences.monitoring.toggle() } label: {
                Image(systemName: state.preferences.monitoring ? "pause.circle" : "play.circle")
            }.help("Pause or resume clipboard monitoring")
            Button(action: state.openSettings) { Image(systemName: "gearshape") }.help("Settings")
            Menu {
                Button("Clear recent history") { state.clear(all: false) }
                Button("Clear all history…", role: .destructive) { clearAll = true }
            } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).frame(width: 20)
        }.buttonStyle(.plain)
    }
    private var historyView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if results.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: search.isEmpty ? "clipboard" : "magnifyingglass").font(.system(size: 40, weight: .light)).foregroundStyle(Design.gold)
                            Text(search.isEmpty ? "Your next idea starts here" : "No matching clips").font(.title3.weight(.medium))
                            Text(search.isEmpty ? "Copy something in any app to keep it here." : "Try a title, label, or a few words.").foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 100)
                    }
                    ForEach([true, false], id: \.self) { pinned in
                        let group = results.filter { $0.pinned == pinned }
                        if !group.isEmpty {
                            Text(pinned ? "PINNED" : "RECENT").font(.caption2.weight(.semibold)).tracking(1.4).foregroundStyle(.secondary).padding(.top, 8).padding(.leading, 10)
                            ForEach(group) { item in
                                ClipRow(item: item, selected: selected?.id == item.id, pin: { state.pin(item) }, copy: { state.copy(item) })
                                    .contentShape(Rectangle())
                                    .onTapGesture { state.selectedID = item.id }
                                    .onTapGesture(count: 2) { state.activate(item) }
                                    .contextMenu {
                                        Button("Copy") { state.copy(item) }
                                        Button("Copy as plain text") { state.copy(item, plain: true) }
                                        Button("Activate") { state.activate(item) }
                                        Button("Activate as plain text") { state.activate(item, plain: true) }
                                        Button(item.pinned ? "Unpin" : "Pin") { state.pin(item) }
                                        Button("Transform with AI…") { state.selectedID = item.id; state.ai.input = item.text; state.ai.sourceID = item.id; state.ai.output = ""; state.tab = "AI" }.disabled(item.kind == .image)
                                        Button("View full content / edit title") { detail = item }
                                        Divider()
                                        Button("Delete", role: .destructive) { state.delete(item) }
                                    }.id(item.id)
                            }
                        }
                    }
                }
            }
            .onChange(of: state.selectedID) { if let id = state.selectedID { proxy.scrollTo(id) } }
        }
    }
    private func move(_ delta: Int) {
        if state.tab == "Emoji" { NotificationCenter.default.post(name: .emojiMove, object: delta * 8); return }
        guard state.tab == "History", !results.isEmpty else { return }
        let index = results.firstIndex { $0.id == selected?.id } ?? 0
        state.selectedID = results[min(max(0, index + delta), results.count - 1)].id
    }
}
struct ClipRow: View {
    let item: ClipItem
    let selected: Bool
    let pin: () -> Void
    let copy: () -> Void
    @State private var hovered = false
    var body: some View {
        HStack(spacing: 12) {
            if item.kind == .image, let thumbnail = MediaService.thumbnail(item) {
                Image(nsImage: thumbnail).resizable().scaledToFit().frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: item.kind.symbol).font(.system(size: 17)).foregroundStyle(Design.gold).frame(width: 28)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(item.preview).font(.system(size: 13, weight: .medium)).lineLimit(2)
                HStack(spacing: 6) {
                    Text(item.kind.rawValue)
                    if let source = item.sourceApp { Text("·"); Text(source).lineLimit(1) }
                    Spacer()
                    Text(item.lastCopiedAt, style: .relative)
                }.font(.caption2).foregroundStyle(.secondary)
            }
            if hovered || selected {
                Button(action: pin) { Image(systemName: item.pinned ? "pin.fill" : "pin") }.help(item.pinned ? "Unpin" : "Pin")
                Button(action: copy) { Image(systemName: "doc.on.doc") }.help("Copy only")
            }
        }.buttonStyle(.plain).padding(12)
        .background(selected ? Design.selection : hovered ? Color.primary.opacity(0.04) : .clear, in: RoundedRectangle(cornerRadius: Design.rowRadius))
        .onHover { hovered = $0 }
        .accessibilityElement(children: .contain)
    }
}
struct ItemDetailView: View {
    @ObservedObject var state: AppState
    let item: ClipItem
    @State private var title = ""
    @State private var extracted = ""
    @State private var extracting = false
    @State private var ocrError = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Clip details").font(.title2)
            TextField("Optional title", text: $title).textFieldStyle(.roundedBorder)
            Text("\(item.kind.rawValue) · \(item.createdAt.formatted())").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let image = MediaService.thumbnail(item) { Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 180) }
                    Text(item.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    if let data = item.imageData {
                        HStack {
                            Button("Extract Text · on this Mac") {
                                extracting = true; ocrError = ""
                                Task {
                                    do { extracted = try await MediaService.extractText(data); if extracted.isEmpty { ocrError = "No readable text found." } }
                                    catch { ocrError = "Text recognition failed for this image." }
                                    extracting = false
                                }
                            }.disabled(extracting)
                            if extracting { ProgressView().controlSize(.small) }
                        }
                    }
                    if !ocrError.isEmpty { Text(ocrError).font(.caption).foregroundStyle(.secondary) }
                    if !extracted.isEmpty {
                        Text(extracted).textSelection(.enabled)
                        Button("Save extracted text") { state.add(ClipItem(text: extracted, kind: Classifier.classify(extracted))); state.message = "Extracted text saved."; dismiss() }
                    }
                }
            }
            HStack {
                Button("Copy") { state.copy(item) }
                Spacer()
                Button("Done") { state.title(item.id, value: title); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 480, height: 440).onAppear { title = item.title ?? "" }
    }
}
