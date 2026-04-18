import Testing
import Foundation
@testable import VetoCore

@Test
func decisionMappingBodyHashIsStableForSameInput() {
    let h1 = DecisionMapping.bodyHash("Trump 2028: chip in $5")
    let h2 = DecisionMapping.bodyHash("Trump 2028: chip in $5")

    #expect(h1 == h2)
    #expect(h1.hasPrefix("sha256:"))
    #expect(h1.count == "sha256:".count + 64)
}

@Test
func decisionMappingBodyHashChangesForDifferentInput() {
    let h1 = DecisionMapping.bodyHash("foo")
    let h2 = DecisionMapping.bodyHash("bar")

    #expect(h1 != h2)
}

@Test
func decisionMappingMakesHistoryEntryForJunkDecision() {
    let now = Date(timeIntervalSince1970: 1_729_123_456)
    let entry = DecisionMapping.makeHistoryEntry(
        decision: .junk(ruleId: "donations.actblue", confidence: 1.0),
        sender: "+15555550100",
        bodyHash: "sha256:abc",
        now: now
    )

    #expect(entry.timestamp == now)
    #expect(entry.sender == "+15555550100")
    #expect(entry.action == .junk(ruleId: "donations.actblue"))
    #expect(entry.bodyHash == "sha256:abc")
    #expect(entry.undone == false)
}

@Test
func decisionMappingMakesHistoryEntryForAllowDecision() {
    let entry = DecisionMapping.makeHistoryEntry(
        decision: .allow(reason: .trustedSender),
        sender: "+15555550200",
        bodyHash: "sha256:def",
        now: Date(timeIntervalSince1970: 1_729_123_456)
    )

    #expect(entry.action == .allow(reason: "trustedSender"))
}

@Test
func decisionMappingMakesHistoryEntryForNoneDecision() {
    let entry = DecisionMapping.makeHistoryEntry(
        decision: .none,
        sender: "+15555550300",
        bodyHash: "sha256:ghi",
        now: Date(timeIntervalSince1970: 1_729_123_456)
    )

    #expect(entry.action == .none)
}
