import Foundation
import CryptoKit

public enum BundleHasher {
    public static func canonicalHash(
        infoPlistURL: URL? = nil,
        packURLs: [URL] = [],
        modelDirectoryURL: URL? = nil
    ) throws -> String {
        var hasher = SHA256()

        if let infoPlistURL {
            let plistData = try Data(contentsOf: infoPlistURL)
            let stripped = try stripSigningKeys(from: plistData)
            hasher.update(data: stripped)
        }

        let sortedPacks = packURLs.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for url in sortedPacks {
            let data = try Data(contentsOf: url)
            try update(&hasher, sectionName: url.lastPathComponent, data: data)
        }

        if let modelURL = modelDirectoryURL {
            let entries = try filesInDirectory(modelURL).sorted { $0.relativePath < $1.relativePath }
            for entry in entries {
                let data = try Data(contentsOf: entry.absoluteURL)
                try update(&hasher, sectionName: entry.relativePath, data: data)
            }
        }

        let digest = hasher.finalize()
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func update(_ hasher: inout SHA256, sectionName: String, data: Data) throws {
        hasher.update(data: Data(sectionName.utf8))
        hasher.update(data: Data([0x0A]))
        hasher.update(data: data)
        hasher.update(data: Data([0x0A]))
    }

    private static func stripSigningKeys(from plistData: Data) throws -> Data {
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard var dict = try PropertyListSerialization.propertyList(
            from: plistData, options: [], format: &format
        ) as? [String: Any] else {
            return plistData
        }
        for key in keysToStripFromInfoPlist {
            dict.removeValue(forKey: key)
        }
        return try PropertyListSerialization.data(fromPropertyList: dict, format: format, options: 0)
    }

    private struct FileEntry {
        let absoluteURL: URL
        let relativePath: String
    }

    private static func filesInDirectory(_ root: URL) throws -> [FileEntry] {
        let standardizedRoot = root.standardizedFileURL
        let rootComponentCount = standardizedRoot.pathComponents.count
        let enumerator = FileManager.default.enumerator(
            at: standardizedRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        )
        var results: [FileEntry] = []
        while let url = enumerator?.nextObject() as? URL {
            let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard resourceValues.isRegularFile == true else { continue }
            let standardized = url.standardizedFileURL
            let components = standardized.pathComponents
            guard components.count > rootComponentCount else { continue }
            let relative = components[rootComponentCount...].joined(separator: "/")
            results.append(FileEntry(absoluteURL: standardized, relativePath: relative))
        }
        return results
    }

    private static let keysToStripFromInfoPlist: Set<String> = [
        "CFBundleSignature",
    ]
}
