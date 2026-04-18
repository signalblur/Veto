import Testing
@testable import VetoCore

private struct FakeDetector: Detector {
    let result: DetectionResult

    func evaluate(_ msg: InboundMessage) async -> DetectionResult {
        result
    }
}

private actor CallCounter {
    private(set) var count: Int = 0

    func increment() {
        count += 1
    }
}

private struct CountingFakeDetector: Detector {
    let result: DetectionResult
    let counter: CallCounter

    func evaluate(_ msg: InboundMessage) async -> DetectionResult {
        await counter.increment()
        return result
    }
}

private let sampleMessage = InboundMessage(sender: "+15555550100", body: "chip in $25")

@Test
func returnsNoneWhenMasterDisabledEvenIfDetectorWouldMatch() async {
    let engine = Engine(detectors: [
        FakeDetector(result: .match(ruleId: "rule.x", confidence: 0.99)),
    ])
    let settings = Settings(masterEnabled: false, threshold: 0.5)

    let decision = await engine.classify(sampleMessage, settings: settings)

    #expect(decision == .none)
}

@Test
func returnsNoneWhenNoDetectorsRegistered() async {
    let engine = Engine(detectors: [])
    let settings = Settings(masterEnabled: true, threshold: 0.5)

    let decision = await engine.classify(sampleMessage, settings: settings)

    #expect(decision == .none)
}

@Test
func explicitAllowShortCircuitsAndSkipsLaterDetectors() async {
    let counter = CallCounter()
    let engine = Engine(detectors: [
        FakeDetector(result: .explicitAllow(reason: .trustedSender)),
        CountingFakeDetector(result: .match(ruleId: "rule.x", confidence: 0.99), counter: counter),
    ])
    let settings = Settings(masterEnabled: true, threshold: 0.5)

    let decision = await engine.classify(sampleMessage, settings: settings)

    #expect(decision == .allow(reason: .trustedSender))
    let observedCount = await counter.count
    #expect(observedCount == 0)
}

@Test
func returnsJunkWhenConfidenceMeetsThreshold() async {
    let engine = Engine(detectors: [
        FakeDetector(result: .match(ruleId: "donations.actblue", confidence: 0.6)),
    ])
    let settings = Settings(masterEnabled: true, threshold: 0.6)

    let decision = await engine.classify(sampleMessage, settings: settings)

    #expect(decision == .junk(ruleId: "donations.actblue", confidence: 0.6))
}

@Test
func returnsNoneWhenConfidenceBelowThreshold() async {
    let engine = Engine(detectors: [
        FakeDetector(result: .match(ruleId: "donations.actblue", confidence: 0.59)),
    ])
    let settings = Settings(masterEnabled: true, threshold: 0.6)

    let decision = await engine.classify(sampleMessage, settings: settings)

    #expect(decision == .none)
}

@Test
func earlyExplicitAllowOverridesLaterMatchThatWouldJunk() async {
    let engine = Engine(detectors: [
        FakeDetector(result: .explicitAllow(reason: .trustedSender)),
        FakeDetector(result: .match(ruleId: "donations.actblue", confidence: 0.99)),
    ])
    let settings = Settings(masterEnabled: true, threshold: 0.5)

    let decision = await engine.classify(sampleMessage, settings: settings)

    #expect(decision == .allow(reason: .trustedSender))
}

@Test
func skipsPassDetectorAndContinuesToNext() async {
    let engine = Engine(detectors: [
        FakeDetector(result: .pass),
        FakeDetector(result: .match(ruleId: "donations.actblue", confidence: 0.9)),
    ])
    let settings = Settings(masterEnabled: true, threshold: 0.5)

    let decision = await engine.classify(sampleMessage, settings: settings)

    #expect(decision == .junk(ruleId: "donations.actblue", confidence: 0.9))
}
