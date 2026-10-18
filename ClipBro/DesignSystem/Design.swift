import SwiftUI
import AppKit

enum Design {
    static let panelWidth: CGFloat = 560
    static let panelHeight: CGFloat = 640
    static let radius: CGFloat = 22
    static let rowRadius: CGFloat = 12
    static let spacing: CGFloat = 14
    static let inset: CGFloat = 22
    static let hoverDuration = 0.12
    static let gold = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.84, green: 0.70, blue: 0.44, alpha: 1)
            : NSColor(calibratedRed: 0.56, green: 0.39, blue: 0.15, alpha: 1)
    })
    static let selection = gold.opacity(0.16)
}
struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
