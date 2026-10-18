import SwiftUI

struct LauncherView: View {
    @ObservedObject var state: AppState
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    var body: some View {
        VStack(spacing: Design.spacing) {
            HStack(spacing: 10) {
                Image(systemName: "clipboard.fill").font(.title2).foregroundStyle(Design.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ClipBro").font(.title2.weight(.semibold))
                    Text("A little less copying. A lot more flow.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { state.preferences.monitoring.toggle() } label: {
                    Image(systemName: state.preferences.monitoring ? "pause.circle" : "play.circle")
                }.help("Pause or resume clipboard monitoring")
                Button(action: state.openSettings) { Image(systemName: "gearshape") }.help("Settings")
            }.buttonStyle(.plain)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search clips, emojis, snippets…", text: $search).textFieldStyle(.plain).focused($searchFocused)
            }.padding(12).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Design.rowRadius))
            Spacer()
            Image(systemName: "clipboard").font(.system(size: 44, weight: .light)).foregroundStyle(Design.gold)
            Text("Your next idea starts here").font(.title3.weight(.medium))
            Text("Copied items will be collected here.").foregroundStyle(.secondary)
            Spacer()
            Divider()
            HStack { Text("↑↓ Navigate    ↵ Activate    Esc Close"); Spacer(); Text("LOCAL FIRST").tracking(1) }
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(Design.inset)
        .frame(width: Design.panelWidth, height: Design.panelHeight)
        .background(GlassBackground())
        .clipShape(RoundedRectangle(cornerRadius: Design.radius))
        .overlay(RoundedRectangle(cornerRadius: Design.radius).strokeBorder(.primary.opacity(0.08)))
        .tint(Design.gold)
        .onChange(of: state.focusSearch) { searchFocused = true }
    }
}
