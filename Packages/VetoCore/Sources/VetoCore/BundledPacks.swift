import Foundation

public enum BundledPacks {
    public static let identifiers = ["donations", "gotv", "surveys", "advocacy"]

    public static func allURLs() -> [URL] {
        identifiers.compactMap { url(for: $0) }
    }

    public static func url(for identifier: String) -> URL? {
        Bundle.module.url(forResource: identifier, withExtension: "json", subdirectory: "Packs")
    }

    public static func loadAll(decoder: JSONDecoder = JSONDecoder()) throws -> [Pack] {
        try allURLs().map { url in
            let data = try Data(contentsOf: url)
            return try decoder.decode(Pack.self, from: data)
        }
    }
}
