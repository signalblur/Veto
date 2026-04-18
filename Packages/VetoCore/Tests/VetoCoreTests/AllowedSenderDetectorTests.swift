import Testing
@testable import VetoCore

@Test
func allowedSenderDetectorReturnsExplicitAllowForTrustedSender() async {
    let detector = AllowedSenderDetector(trustedSenders: ["+15555550100", "+15555550200"])
    let msg = InboundMessage(sender: "+15555550100", body: "Trump 2028: chip in $5")

    let result = await detector.evaluate(msg)

    #expect(result == .explicitAllow(reason: .trustedSender))
}

@Test
func allowedSenderDetectorReturnsPassForUntrustedSender() async {
    let detector = AllowedSenderDetector(trustedSenders: ["+15555550100"])
    let msg = InboundMessage(sender: "+15555559999", body: "WinRed: chip in $25")

    let result = await detector.evaluate(msg)

    #expect(result == .pass)
}

@Test
func allowedSenderDetectorReturnsPassForEmptyTrustedSet() async {
    let detector = AllowedSenderDetector(trustedSenders: [])
    let msg = InboundMessage(sender: "+15555550100", body: "anything")

    let result = await detector.evaluate(msg)

    #expect(result == .pass)
}

@Test
func allowedSenderDetectorMatchesAreExactStrings() async {
    let detector = AllowedSenderDetector(trustedSenders: ["+15555550100"])
    let msg = InboundMessage(sender: "5555550100", body: "test")

    let result = await detector.evaluate(msg)

    #expect(result == .pass)
}

@Test
func allowedSenderDetectorEngineIntegrationShortCircuitsBeforeJunk() async {
    let allowed = AllowedSenderDetector(trustedSenders: ["+15555550100"])
    let alwaysJunk = AlwaysJunkFakeDetector()
    let engine = Engine(detectors: [allowed, alwaysJunk])
    let settings = Settings(masterEnabled: true, threshold: 0.5)
    let msg = InboundMessage(sender: "+15555550100", body: "ActBlue: chip in $25")

    let decision = await engine.classify(msg, settings: settings)

    #expect(decision == .allow(reason: .trustedSender))
}

private struct AlwaysJunkFakeDetector: Detector {
    func evaluate(_ msg: InboundMessage) async -> DetectionResult {
        .match(ruleId: "fake.always", confidence: 0.99)
    }
}
