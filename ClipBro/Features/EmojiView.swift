import SwiftUI

struct EmojiPicker: View {
    @ObservedObject var state: AppState
    let search: String
    @State private var category = "All"
    @State private var selection = 0
    @AppStorage("emojiRecents") private var recentData = ""
    @AppStorage("emojiFavorites") private var favoriteData = ""
    var favorites: [String] { favoriteData.components(separatedBy: "|").filter { !$0.isEmpty } }
    var recents: [String] { recentData.components(separatedBy: "|").filter { !$0.isEmpty } }
    var results: [Emoji] {
        let collection = category == "Recent" ? recents.compactMap { symbol in Emoji.all.first { $0.symbol == symbol } } : Emoji.all
        return collection.filter { $0.matches(search) && (category == "All" || category == "Recent" || (category == "Favorites" ? favorites.contains($0.symbol) : $0.category == category)) }
    }
    var body: some View {
        VStack {
            HStack {
                Picker("Category", selection: $category) {
                    ForEach(["All", "Recent", "Favorites", "Smileys", "People", "Gestures", "Animals", "Food", "Travel", "Objects", "Symbols", "Flags"], id: \.self) { Text($0) }
                }.labelsHidden().frame(width: 160)
                Spacer()
                Text("Right-click to favorite").font(.caption).foregroundStyle(.secondary)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 8) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, emoji in
                            Button { use(emoji) } label: {
                                Text(emoji.symbol).font(.system(size: 28)).frame(maxWidth: .infinity).frame(height: 45)
                                    .background(index == selection ? Design.selection : .clear, in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain).help(emoji.name).accessibilityLabel(emoji.name).id(index)
                            .contextMenu { Button(favorites.contains(emoji.symbol) ? "Remove favorite" : "Favorite") { favorite(emoji) } }
                        }
                    }
                    if results.isEmpty { Text("No emojis here yet.").foregroundStyle(.secondary).padding(50) }
                }.onChange(of: selection) { proxy.scrollTo(selection) }
            }
        }
        .onChange(of: category) { selection = 0 }
        .onChange(of: search) { selection = 0 }
        .onKeyPress(.downArrow) { move(8); return .handled }
        .onKeyPress(.upArrow) { move(-8); return .handled }
        .onKeyPress(.rightArrow) { move(1); return .handled }
        .onKeyPress(.leftArrow) { move(-1); return .handled }
        .onKeyPress(.return) { if results.indices.contains(selection) { use(results[selection]) }; return .handled }
        .onReceive(NotificationCenter.default.publisher(for: .emojiActivate)) { _ in
            if results.indices.contains(selection) { use(results[selection]) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .emojiMove)) { note in move(note.object as? Int ?? 0) }
    }
    private func move(_ offset: Int) { selection = min(max(0, selection + offset), max(0, results.count - 1)) }
    private func use(_ emoji: Emoji) {
        recentData = ([emoji.symbol] + recents.filter { $0 != emoji.symbol }).prefix(32).joined(separator: "|")
        state.activate(ClipItem(text: emoji.symbol, kind: .text))
    }
    private func favorite(_ emoji: Emoji) {
        favoriteData = (favorites.contains(emoji.symbol) ? favorites.filter { $0 != emoji.symbol } : favorites + [emoji.symbol]).joined(separator: "|")
    }
}
extension Notification.Name {
    static let emojiActivate = Notification.Name("ClipBro.emojiActivate")
    static let emojiMove = Notification.Name("ClipBro.emojiMove")
}
