import Testing
@testable import VetoCore

@Test
func signatureDetectorMatchesSimpleRegexAndReturnsFullConfidence() async throws {
    let pack = Pack(
        id: "p", version: "v", displayName: "P", threshold: 50,
        rules: [Rule(id: "r1", weight: 50, match: .regex("(?i)donate"))]
    )
    let detector = try SignatureDetector(packs: [pack])
    let msg = InboundMessage(sender: "+15555550100", body: "Please DONATE today")

    let result = await detector.evaluate(msg)

    #expect(result == .match(ruleId: "r1", confidence: 1.0))
}

@Test
func signatureDetectorReturnsPassWhenScoreBelowThreshold() async throws {
    let pack = Pack(
        id: "p", version: "v", displayName: "P", threshold: 100,
        rules: [Rule(id: "r1", weight: 50, match: .regex("donate"))]
    )
    let detector = try SignatureDetector(packs: [pack])
    let msg = InboundMessage(sender: "+15555550100", body: "donate now")

    #expect(await detector.evaluate(msg) == .pass)
}

@Test
func signatureDetectorSumsWeightsAcrossMatchingRulesAndPicksHighestWeightRuleId() async throws {
    let pack = Pack(
        id: "p", version: "v", displayName: "P", threshold: 100,
        rules: [
            Rule(id: "r.low", weight: 40, match: .regex("urgent")),
            Rule(id: "r.high", weight: 60, match: .regex("donate")),
        ]
    )
    let detector = try SignatureDetector(packs: [pack])
    let msg = InboundMessage(sender: "+15555550100", body: "urgent: please donate")

    let result = await detector.evaluate(msg)

    #expect(result == .match(ruleId: "r.high", confidence: 1.0))
}

@Test
func signatureDetectorAnyExpressionFiresIfAnyChildMatches() async throws {
    let pack = Pack(
        id: "p", version: "v", displayName: "P", threshold: 50,
        rules: [Rule(id: "r1", weight: 50, match: .any([.regex("foo"), .regex("bar")]))]
    )
    let detector = try SignatureDetector(packs: [pack])

    #expect(await detector.evaluate(InboundMessage(sender: "+1", body: "has bar in it")) == .match(ruleId: "r1", confidence: 1.0))
    #expect(await detector.evaluate(InboundMessage(sender: "+1", body: "no match")) == .pass)
}

@Test
func signatureDetectorAllExpressionRequiresEveryChild() async throws {
    let pack = Pack(
        id: "p", version: "v", displayName: "P", threshold: 50,
        rules: [Rule(id: "r1", weight: 50, match: .all([.regex("foo"), .regex("bar")]))]
    )
    let detector = try SignatureDetector(packs: [pack])

    #expect(await detector.evaluate(InboundMessage(sender: "+1", body: "foo only")) == .pass)
    #expect(await detector.evaluate(InboundMessage(sender: "+1", body: "foo and bar together")) == .match(ruleId: "r1", confidence: 1.0))
}

@Test
func signatureDetectorEmptyPackListReturnsPass() async throws {
    let detector = try SignatureDetector(packs: [])
    #expect(await detector.evaluate(InboundMessage(sender: "+1", body: "anything")) == .pass)
}

@Test
func signatureDetectorEvaluatesPacksInOrderAndReturnsFirstMatch() async throws {
    let firstPack = Pack(
        id: "first", version: "v", displayName: "First", threshold: 50,
        rules: [Rule(id: "first.rule", weight: 50, match: .regex("trigger"))]
    )
    let secondPack = Pack(
        id: "second", version: "v", displayName: "Second", threshold: 50,
        rules: [Rule(id: "second.rule", weight: 50, match: .regex("trigger"))]
    )
    let detector = try SignatureDetector(packs: [firstPack, secondPack])
    let msg = InboundMessage(sender: "+1", body: "trigger word")

    let result = await detector.evaluate(msg)

    #expect(result == .match(ruleId: "first.rule", confidence: 1.0))
}

@Test
func signatureDetectorRejectsInvalidRegexAtConstructionTime() {
    let pack = Pack(
        id: "p", version: "v", displayName: "P", threshold: 50,
        rules: [Rule(id: "bad", weight: 50, match: .regex("[unclosed"))]
    )
    #expect(throws: PackLoadError.self) {
        _ = try SignatureDetector(packs: [pack])
    }
}

@Test
func signatureDetectorRejectsDuplicateRuleIdsWithinAPack() {
    let pack = Pack(
        id: "p", version: "v", displayName: "P", threshold: 50,
        rules: [
            Rule(id: "dup", weight: 50, match: .regex("a")),
            Rule(id: "dup", weight: 50, match: .regex("b")),
        ]
    )
    #expect(throws: PackLoadError.self) {
        _ = try SignatureDetector(packs: [pack])
    }
}

@Test
func signatureDetectorRejectsEmptyRulesPack() {
    let pack = Pack(id: "p", version: "v", displayName: "P", threshold: 50, rules: [])
    #expect(throws: PackLoadError.self) {
        _ = try SignatureDetector(packs: [pack])
    }
}

@Test
func packLoadErrorCarriesRuleIdContextForInvalidRegex() {
    let pack = Pack(
        id: "p", version: "v", displayName: "P", threshold: 50,
        rules: [Rule(id: "the-bad-rule", weight: 50, match: .regex("[unclosed"))]
    )
    do {
        _ = try SignatureDetector(packs: [pack])
        Issue.record("expected throw")
    } catch let error as PackLoadError {
        if case .invalidRegex(let ruleId, _, _) = error {
            #expect(ruleId == "the-bad-rule")
        } else {
            Issue.record("expected .invalidRegex, got \(error)")
        }
    } catch {
        Issue.record("unexpected error type: \(error)")
    }
}
