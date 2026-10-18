import Foundation

struct Preferences: Codable, Equatable {
    var monitoring = true
    var persistence = true
    var historyLimit = 20
    var pinLimit = 50
    var showOnLaunch = false
    var pasteOnActivate = false
    var skipSensitive = true
    var excludedApps = "com.1password.1password,com.agilebits.onepassword7,com.apple.keychainaccess"
    var theme = "System"
    var defaultTab = "History"
    var animations = true
    var imageLimitMB = 50
    var aiEnabled = false
    var model = "gpt-4.1-mini"
    var customPrompt = "Rewrite clearly while preserving the original meaning."
    var hotkeyCode: UInt32 = 9
    var hotkeyModifiers: UInt32 = 768
    static func load(from defaults: UserDefaults = .standard) -> Self {
        guard let data = defaults.data(forKey: "preferences"), let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }
    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "preferences") }
    }
}
