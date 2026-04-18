import Testing
import Foundation
@testable import VetoCore

private func makeTempContainer() -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("VetoCoreTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func cleanup(_ container: URL) {
    try? FileManager.default.removeItem(at: container)
}

@Test
func appGroupStoreLoadSettingsReturnsDefaultsForFreshContainer() async throws {
    let container = makeTempContainer()
    defer { cleanup(container) }
    let store = AppGroupStore(containerURL: container)

    let settings = try await store.loadSettings()

    #expect(settings.masterEnabled == true)
    #expect(settings.threshold == 0.5)
}

@Test
func appGroupStoreSaveSettingsRoundTripsThroughLoadSettings() async throws {
    let container = makeTempContainer()
    defer { cleanup(container) }
    let store = AppGroupStore(containerURL: container)
    let custom = Settings(masterEnabled: false, threshold: 0.9)

    try await store.saveSettings(custom)
    let loaded = try await store.loadSettings()

    #expect(loaded == custom)
}

@Test
func appGroupStoreLoadAllowedSendersReturnsEmptySetForFreshContainer() async throws {
    let container = makeTempContainer()
    defer { cleanup(container) }
    let store = AppGroupStore(containerURL: container)

    let senders = try await store.loadAllowedSenders()

    #expect(senders.isEmpty)
}

@Test
func appGroupStoreAddAllowedSenderPersists() async throws {
    let container = makeTempContainer()
    defer { cleanup(container) }
    let store = AppGroupStore(containerURL: container)

    try await store.addAllowedSender("+15555550100")
    try await store.addAllowedSender("+15555550200")
    let senders = try await store.loadAllowedSenders()

    #expect(senders == ["+15555550100", "+15555550200"])
}

@Test
func appGroupStoreAddAllowedSenderIsIdempotent() async throws {
    let container = makeTempContainer()
    defer { cleanup(container) }
    let store = AppGroupStore(containerURL: container)

    try await store.addAllowedSender("+15555550100")
    try await store.addAllowedSender("+15555550100")
    let senders = try await store.loadAllowedSenders()

    #expect(senders == ["+15555550100"])
}

@Test
func appGroupStoreRemoveAllowedSenderRemovesIt() async throws {
    let container = makeTempContainer()
    defer { cleanup(container) }
    let store = AppGroupStore(containerURL: container)
    try await store.addAllowedSender("+15555550100")
    try await store.addAllowedSender("+15555550200")

    try await store.removeAllowedSender("+15555550100")
    let senders = try await store.loadAllowedSenders()

    #expect(senders == ["+15555550200"])
}

@Test
func appGroupStoreLoadPacksReturnsEmptyForFreshContainer() async throws {
    let container = makeTempContainer()
    defer { cleanup(container) }
    let store = AppGroupStore(containerURL: container)

    let packs = try await store.loadPacks()

    #expect(packs.isEmpty)
}

@Test
func appGroupStoreInstallPacksCopiesAndLoadPacksReadsThem() async throws {
    let container = makeTempContainer()
    defer { cleanup(container) }
    let store = AppGroupStore(containerURL: container)

    let sourceDir = container.appendingPathComponent("source", isDirectory: true)
    try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

    let pack1 = Pack(id: "donations", version: "1", displayName: "Donations", threshold: 50,
                     rules: [Rule(id: "r1", weight: 50, match: .regex("donate"))])
    let pack2 = Pack(id: "gotv", version: "1", displayName: "GOTV", threshold: 50,
                     rules: [Rule(id: "r1", weight: 50, match: .regex("vote"))])

    let pack1URL = sourceDir.appendingPathComponent("donations.json")
    let pack2URL = sourceDir.appendingPathComponent("gotv.json")
    try JSONEncoder().encode(pack1).write(to: pack1URL)
    try JSONEncoder().encode(pack2).write(to: pack2URL)

    try await store.installPacks(from: [pack1URL, pack2URL])
    let loaded = try await store.loadPacks()

    #expect(loaded.count == 2)
    #expect(loaded.map(\.id).sorted() == ["donations", "gotv"])
}

@Test
func appGroupStoreInstallPacksReplacesExistingPacksDirectory() async throws {
    let container = makeTempContainer()
    defer { cleanup(container) }
    let store = AppGroupStore(containerURL: container)

    let sourceDir = container.appendingPathComponent("source", isDirectory: true)
    try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

    let v1 = Pack(id: "donations", version: "1", displayName: "Donations", threshold: 50,
                  rules: [Rule(id: "r1", weight: 50, match: .regex("v1"))])
    let v1URL = sourceDir.appendingPathComponent("donations.json")
    try JSONEncoder().encode(v1).write(to: v1URL)
    try await store.installPacks(from: [v1URL])

    let v2 = Pack(id: "donations", version: "2", displayName: "Donations", threshold: 50,
                  rules: [Rule(id: "r1", weight: 50, match: .regex("v2"))])
    let v2URL = sourceDir.appendingPathComponent("donations.json")
    try JSONEncoder().encode(v2).write(to: v2URL)
    try await store.installPacks(from: [v2URL])

    let loaded = try await store.loadPacks()

    #expect(loaded.count == 1)
    #expect(loaded[0].version == "2")
}

@Test
func appGroupStoreSkipsMalformedPackFilesOnLoad() async throws {
    let container = makeTempContainer()
    defer { cleanup(container) }
    let store = AppGroupStore(containerURL: container)

    let packsDir = container.appendingPathComponent("packs", isDirectory: true)
    try FileManager.default.createDirectory(at: packsDir, withIntermediateDirectories: true)

    let goodPack = Pack(id: "good", version: "1", displayName: "Good", threshold: 50,
                        rules: [Rule(id: "r", weight: 50, match: .regex("x"))])
    try JSONEncoder().encode(goodPack).write(to: packsDir.appendingPathComponent("good.json"))
    try Data("not json at all".utf8).write(to: packsDir.appendingPathComponent("bad.json"))

    let loaded = try await store.loadPacks()

    #expect(loaded.count == 1)
    #expect(loaded[0].id == "good")
}
