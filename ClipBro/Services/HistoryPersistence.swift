import Foundation

struct HistoryPersistence {
    let directory: URL
    var file: URL { directory.appendingPathComponent("history.json") }
    static var standard: Self {
        Self(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ClipBro", isDirectory: true))
    }
    func load() throws -> History {
        guard FileManager.default.fileExists(atPath: file.path) else { return History() }
        let data = try Data(contentsOf: file)
        guard data.count <= 32 * 1024 * 1024 else { throw StorageError.tooLarge }
        let history = try JSONDecoder().decode(History.self, from: data)
        guard history.version == 1 else { throw StorageError.version }
        return history
    }
    func save(_ history: History) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(history).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
    func clear() throws {
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
    enum StorageError: Error { case tooLarge, version }
}
