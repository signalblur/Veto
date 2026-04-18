import Foundation

public actor HistoryLog {
    public let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(url: URL) {
        self.url = url
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        self.encoder = enc
        self.decoder = JSONDecoder()
    }

    public func append(_ entry: HistoryEntry) throws {
        try ensureContainerDirectoryExists()
        try ensureFileExists()

        var line = try encoder.encode(entry)
        line.append(0x0A)

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    public func entries() throws -> [HistoryEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        return parseLines(in: data)
    }

    public func compact(keepingMostRecent maxEntries: Int) throws {
        let all = try entries()
        guard all.count > maxEntries else { return }
        let kept = Array(all.suffix(maxEntries))
        try rewrite(entries: kept)
    }

    public func markUndone(bodyHash: String, sender: String) throws {
        let all = try entries()
        let updated = all.map { entry -> HistoryEntry in
            guard entry.bodyHash == bodyHash, entry.sender == sender, !entry.undone else {
                return entry
            }
            var copy = entry
            copy.undone = true
            return copy
        }
        try rewrite(entries: updated)
    }

    private func parseLines(in data: Data) -> [HistoryEntry] {
        var entries: [HistoryEntry] = []
        var lineStart = data.startIndex
        for index in data.indices {
            if data[index] == 0x0A {
                let lineData = data[lineStart..<index]
                if !lineData.isEmpty, let entry = try? decoder.decode(HistoryEntry.self, from: lineData) {
                    entries.append(entry)
                }
                lineStart = data.index(after: index)
            }
        }
        if lineStart < data.endIndex {
            let trailing = data[lineStart..<data.endIndex]
            if let entry = try? decoder.decode(HistoryEntry.self, from: trailing) {
                entries.append(entry)
            }
        }
        return entries
    }

    private func rewrite(entries: [HistoryEntry]) throws {
        try ensureContainerDirectoryExists()
        var out = Data()
        for entry in entries {
            let line = try encoder.encode(entry)
            out.append(line)
            out.append(0x0A)
        }
        try out.write(to: url, options: .atomic)
    }

    private func ensureContainerDirectoryExists() throws {
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func ensureFileExists() throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
    }
}
