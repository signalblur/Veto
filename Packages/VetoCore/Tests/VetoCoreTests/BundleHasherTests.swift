import Testing
import Foundation
@testable import VetoCore

private func makeTempDir() -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("VetoCoreTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func writePlist(_ dict: [String: Any], to url: URL) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
    try data.write(to: url)
}

@Test
func bundleHasherIsDeterministicForIdenticalInputs() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let plistURL = dir.appendingPathComponent("Info.plist")
    try writePlist(["CFBundleIdentifier": "com.example.veto", "CFBundleVersion": "1"], to: plistURL)
    let packURL = dir.appendingPathComponent("donations.json")
    try Data(#"{"id":"donations"}"#.utf8).write(to: packURL)

    let h1 = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [packURL], modelDirectoryURL: nil)
    let h2 = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [packURL], modelDirectoryURL: nil)
    let h3 = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [packURL], modelDirectoryURL: nil)

    #expect(h1 == h2)
    #expect(h2 == h3)
    #expect(h1.hasPrefix("sha256:"))
}

@Test
func bundleHasherChangesWhenInfoPlistContentChanges() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let plistURL = dir.appendingPathComponent("Info.plist")
    let packURL = dir.appendingPathComponent("p.json")
    try Data("{}".utf8).write(to: packURL)

    try writePlist(["CFBundleVersion": "1"], to: plistURL)
    let h1 = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [packURL], modelDirectoryURL: nil)

    try writePlist(["CFBundleVersion": "2"], to: plistURL)
    let h2 = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [packURL], modelDirectoryURL: nil)

    #expect(h1 != h2)
}

@Test
func bundleHasherChangesWhenPackContentChanges() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let plistURL = dir.appendingPathComponent("Info.plist")
    try writePlist(["CFBundleVersion": "1"], to: plistURL)
    let packURL = dir.appendingPathComponent("p.json")

    try Data(#"{"v":1}"#.utf8).write(to: packURL)
    let h1 = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [packURL], modelDirectoryURL: nil)

    try Data(#"{"v":2}"#.utf8).write(to: packURL)
    let h2 = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [packURL], modelDirectoryURL: nil)

    #expect(h1 != h2)
}

@Test
func bundleHasherChangesWhenModelDirectoryContentChanges() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let plistURL = dir.appendingPathComponent("Info.plist")
    try writePlist(["CFBundleVersion": "1"], to: plistURL)

    let modelDir = dir.appendingPathComponent("model.mlmodelc", isDirectory: true)
    try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
    let weightsURL = modelDir.appendingPathComponent("weights.bin")

    try Data([0x00, 0x01, 0x02]).write(to: weightsURL)
    let h1 = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [], modelDirectoryURL: modelDir)

    try Data([0x00, 0x01, 0x99]).write(to: weightsURL)
    let h2 = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [], modelDirectoryURL: modelDir)

    #expect(h1 != h2)
}

@Test
func bundleHasherIsOrderIndependentForPackURLArray() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let plistURL = dir.appendingPathComponent("Info.plist")
    try writePlist(["CFBundleVersion": "1"], to: plistURL)
    let p1 = dir.appendingPathComponent("a.json")
    let p2 = dir.appendingPathComponent("b.json")
    try Data(#"{"id":"a"}"#.utf8).write(to: p1)
    try Data(#"{"id":"b"}"#.utf8).write(to: p2)

    let h1 = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [p1, p2], modelDirectoryURL: nil)
    let h2 = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [p2, p1], modelDirectoryURL: nil)

    #expect(h1 == h2)
}

@Test
func bundleHasherStripsCFBundleSignatureBeforeHashing() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let plistURL = dir.appendingPathComponent("Info.plist")

    try writePlist(["CFBundleVersion": "1", "CFBundleSignature": "????"], to: plistURL)
    let withSig = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [], modelDirectoryURL: nil)

    try writePlist(["CFBundleVersion": "1"], to: plistURL)
    let withoutSig = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [], modelDirectoryURL: nil)

    #expect(withSig == withoutSig)
}

@Test
func bundleHasherWorksWithoutModelDirectory() throws {
    let dir = makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let plistURL = dir.appendingPathComponent("Info.plist")
    try writePlist(["CFBundleVersion": "1"], to: plistURL)

    let hash = try BundleHasher.canonicalHash(infoPlistURL: plistURL, packURLs: [], modelDirectoryURL: nil)

    #expect(hash.hasPrefix("sha256:"))
    #expect(hash.count == "sha256:".count + 64)
}
