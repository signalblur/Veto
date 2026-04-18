import Testing
import Foundation
@testable import VetoCore

private func makeTempLogURL() -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("VetoCoreTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("history.jsonl")
}

private func cleanup(_ url: URL) {
    try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
}

@Test
func historyEntryRoundTripsForJunkAction() throws {
    let entry = HistoryEntry(
        timestamp: Date(timeIntervalSince1970: 1_729_123_456),
        sender: "+15555550100",
        action: .junk(ruleId: "donations.actblue"),
        bodyHash: "sha256:abc",
        undone: false
    )

    let data = try JSONEncoder().encode(entry)
    let decoded = try JSONDecoder().decode(HistoryEntry.self, from: data)

    #expect(decoded == entry)
}

@Test
func historyEntryRoundTripsForAllowAction() throws {
    let entry = HistoryEntry(
        timestamp: Date(timeIntervalSince1970: 1_729_123_456),
        sender: "+15555550100",
        action: .allow(reason: "trustedSender"),
        bodyHash: "sha256:def",
        undone: false
    )

    let data = try JSONEncoder().encode(entry)
    let decoded = try JSONDecoder().decode(HistoryEntry.self, from: data)

    #expect(decoded == entry)
}

@Test
func historyEntryRoundTripsForNoneAction() throws {
    let entry = HistoryEntry(
        timestamp: Date(timeIntervalSince1970: 1_729_123_456),
        sender: "+15555550100",
        action: .none,
        bodyHash: "sha256:ghi",
        undone: false
    )

    let data = try JSONEncoder().encode(entry)
    let decoded = try JSONDecoder().decode(HistoryEntry.self, from: data)

    #expect(decoded == entry)
}

@Test
func historyEntryEncodesActionAsStringDiscriminator() throws {
    let entry = HistoryEntry(
        timestamp: Date(timeIntervalSince1970: 1_729_123_456),
        sender: "+15555550100",
        action: .junk(ruleId: "donations.actblue"),
        bodyHash: "sha256:abc",
        undone: false
    )

    let data = try JSONEncoder().encode(entry)
    let json = try #require(String(data: data, encoding: .utf8))

    #expect(json.contains("\"action\":\"junk\""))
    #expect(json.contains("\"ruleId\":\"donations.actblue\""))
    #expect(json.contains("\"ts\":1729123456"))
}

@Test
func historyEntryDecodeRejectsUnknownActionString() {
    let json = #"{"ts":1729123456,"sender":"+1","action":"bogus","bodyHash":"x","undone":false}"#
    #expect(throws: DecodingError.self) {
        _ = try JSONDecoder().decode(HistoryEntry.self, from: Data(json.utf8))
    }
}

@Test
func historyLogEntriesIsEmptyForNonExistentFile() async throws {
    let url = makeTempLogURL()
    defer { cleanup(url) }
    let log = HistoryLog(url: url)

    let entries = try await log.entries()

    #expect(entries.isEmpty)
}

@Test
func historyLogAppendThenEntriesReturnsTheEntry() async throws {
    let url = makeTempLogURL()
    defer { cleanup(url) }
    let log = HistoryLog(url: url)
    let entry = HistoryEntry(
        timestamp: Date(timeIntervalSince1970: 1_729_123_456),
        sender: "+15555550100",
        action: .junk(ruleId: "donations.actblue"),
        bodyHash: "sha256:abc",
        undone: false
    )

    try await log.append(entry)
    let entries = try await log.entries()

    #expect(entries == [entry])
}

@Test
func historyLogPreservesAppendOrder() async throws {
    let url = makeTempLogURL()
    defer { cleanup(url) }
    let log = HistoryLog(url: url)
    let entries = (0..<5).map { i in
        HistoryEntry(
            timestamp: Date(timeIntervalSince1970: TimeInterval(1_729_123_000 + i)),
            sender: "+1555555010\(i)",
            action: .junk(ruleId: "rule.\(i)"),
            bodyHash: "sha256:\(i)",
            undone: false
        )
    }

    for entry in entries {
        try await log.append(entry)
    }
    let read = try await log.entries()

    #expect(read == entries)
}

@Test
func historyLogSkipsMalformedLinesWithoutCrashing() async throws {
    let url = makeTempLogURL()
    defer { cleanup(url) }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let goodLine = #"{"ts":1729123456,"sender":"+1","action":"none","bodyHash":"x","undone":false}"# + "\n"
    let badLine = "this is not json\n"
    let mixed = (goodLine + badLine + goodLine).data(using: .utf8)!
    try mixed.write(to: url)
    let log = HistoryLog(url: url)

    let entries = try await log.entries()

    #expect(entries.count == 2)
}

@Test
func historyLogCompactKeepsMostRecentEntries() async throws {
    let url = makeTempLogURL()
    defer { cleanup(url) }
    let log = HistoryLog(url: url)
    for i in 0..<10 {
        try await log.append(HistoryEntry(
            timestamp: Date(timeIntervalSince1970: TimeInterval(1_729_123_000 + i)),
            sender: "+1",
            action: .none,
            bodyHash: "h\(i)",
            undone: false
        ))
    }

    try await log.compact(keepingMostRecent: 3)
    let entries = try await log.entries()

    #expect(entries.count == 3)
    #expect(entries.map(\.bodyHash) == ["h7", "h8", "h9"])
}

@Test
func historyLogCompactIsNoOpWhenUnderLimit() async throws {
    let url = makeTempLogURL()
    defer { cleanup(url) }
    let log = HistoryLog(url: url)
    for i in 0..<3 {
        try await log.append(HistoryEntry(
            timestamp: Date(timeIntervalSince1970: TimeInterval(1_729_123_000 + i)),
            sender: "+1",
            action: .none,
            bodyHash: "h\(i)",
            undone: false
        ))
    }

    try await log.compact(keepingMostRecent: 500)
    let entries = try await log.entries()

    #expect(entries.count == 3)
}

@Test
func historyLogMarkUndoneFlipsUndoneOnMatchingEntryByBodyHashAndSender() async throws {
    let url = makeTempLogURL()
    defer { cleanup(url) }
    let log = HistoryLog(url: url)
    let target = HistoryEntry(
        timestamp: Date(timeIntervalSince1970: 1_729_123_456),
        sender: "+15555550100",
        action: .junk(ruleId: "donations.actblue"),
        bodyHash: "sha256:abc",
        undone: false
    )
    let other = HistoryEntry(
        timestamp: Date(timeIntervalSince1970: 1_729_123_457),
        sender: "+15555559999",
        action: .junk(ruleId: "donations.actblue"),
        bodyHash: "sha256:xyz",
        undone: false
    )
    try await log.append(target)
    try await log.append(other)

    try await log.markUndone(bodyHash: "sha256:abc", sender: "+15555550100")
    let entries = try await log.entries()

    #expect(entries.count == 2)
    #expect(entries[0].undone == true)
    #expect(entries[1].undone == false)
}
