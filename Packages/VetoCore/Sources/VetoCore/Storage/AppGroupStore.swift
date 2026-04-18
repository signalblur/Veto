import Foundation

public actor AppGroupStore {
    public let containerURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(containerURL: URL) {
        self.containerURL = containerURL
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        self.encoder = enc
        self.decoder = JSONDecoder()
    }

    public func loadSettings() throws -> Settings {
        let url = settingsURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return Settings(masterEnabled: true, threshold: 0.5)
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(Settings.self, from: data)
    }

    public func saveSettings(_ settings: Settings) throws {
        try ensureContainer()
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    public func loadAllowedSenders() throws -> Set<String> {
        let url = allowedSendersURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        let array = try decoder.decode([String].self, from: data)
        return Set(array)
    }

    public func saveAllowedSenders(_ senders: Set<String>) throws {
        try ensureContainer()
        let sorted = senders.sorted()
        let data = try encoder.encode(sorted)
        try data.write(to: allowedSendersURL, options: .atomic)
    }

    public func addAllowedSender(_ sender: String) throws {
        var current = try loadAllowedSenders()
        current.insert(sender)
        try saveAllowedSenders(current)
    }

    public func removeAllowedSender(_ sender: String) throws {
        var current = try loadAllowedSenders()
        current.remove(sender)
        try saveAllowedSenders(current)
    }

    public func loadPacks() throws -> [Pack] {
        let dir = packsDirectoryURL
        guard FileManager.default.fileExists(atPath: dir.path) else {
            return []
        }
        let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let jsonURLs = contents
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var packs: [Pack] = []
        for url in jsonURLs {
            guard let data = try? Data(contentsOf: url),
                  let pack = try? decoder.decode(Pack.self, from: data) else {
                continue
            }
            packs.append(pack)
        }
        return packs
    }

    public func installPacks(from sourceURLs: [URL]) throws {
        try ensureContainer()
        let dir = packsDirectoryURL
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for source in sourceURLs {
            let dest = dir.appendingPathComponent(source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: dest)
        }
    }

    private var settingsURL: URL { containerURL.appendingPathComponent("settings.json") }
    private var allowedSendersURL: URL { containerURL.appendingPathComponent("allowed-senders.json") }
    private var packsDirectoryURL: URL { containerURL.appendingPathComponent("packs", isDirectory: true) }

    private func ensureContainer() throws {
        if !FileManager.default.fileExists(atPath: containerURL.path) {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        }
    }
}
