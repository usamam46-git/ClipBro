import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var preferences = Preferences.load() { didSet { preferences.save() } }
    @Published var focusSearch = UUID()
    @Published var message = ""
    var dismiss: () -> Void = {}
    var openSettings: () -> Void = {}
}
