import Testing
@testable import VetoCore

@Test
func coreMLDetectorReturnsMatchWhenProviderConfidenceMeetsThreshold() async {
    let detector = CoreMLDetector(confidenceThreshold: 0.85, provider: { _ in 0.85 })
    let msg = InboundMessage(sender: "+1", body: "any body")

    let result = await detector.evaluate(msg)

    #expect(result == .match(ruleId: "ml.coreml", confidence: 0.85))
}

@Test
func coreMLDetectorReturnsMatchWhenProviderConfidenceExceedsThreshold() async {
    let detector = CoreMLDetector(confidenceThreshold: 0.85, provider: { _ in 0.95 })

    let result = await detector.evaluate(InboundMessage(sender: "+1", body: "x"))

    #expect(result == .match(ruleId: "ml.coreml", confidence: 0.95))
}

@Test
func coreMLDetectorReturnsPassWhenProviderConfidenceBelowThreshold() async {
    let detector = CoreMLDetector(confidenceThreshold: 0.85, provider: { _ in 0.50 })

    #expect(await detector.evaluate(InboundMessage(sender: "+1", body: "x")) == .pass)
}

@Test
func coreMLDetectorReturnsPassWhenProviderReturnsNil() async {
    let detector = CoreMLDetector(confidenceThreshold: 0.85, provider: { _ in nil })

    #expect(await detector.evaluate(InboundMessage(sender: "+1", body: "x")) == .pass)
}

@Test
func coreMLDetectorPassesMessageBodyToProvider() async {
    actor BodyCollector {
        private(set) var lastBody: String?
        func record(_ body: String) { lastBody = body }
    }
    let collector = BodyCollector()
    let detector = CoreMLDetector(confidenceThreshold: 0.5) { body in
        await collector.record(body)
        return 0.0
    }

    _ = await detector.evaluate(InboundMessage(sender: "+1", body: "the exact body"))

    #expect(await collector.lastBody == "the exact body")
}

@Test
func foundationModelsDetectorReturnsMatchOnPositiveProviderResult() async {
    let detector = FoundationModelsDetector(provider: { _ in true })

    let result = await detector.evaluate(InboundMessage(sender: "+1", body: "x"))

    #expect(result == .match(ruleId: "ml.foundation-models", confidence: 1.0))
}

@Test
func foundationModelsDetectorReturnsPassOnNegativeProviderResult() async {
    let detector = FoundationModelsDetector(provider: { _ in false })

    #expect(await detector.evaluate(InboundMessage(sender: "+1", body: "x")) == .pass)
}

@Test
func foundationModelsDetectorReturnsPassOnNilProviderResult() async {
    let detector = FoundationModelsDetector(provider: { _ in nil })

    #expect(await detector.evaluate(InboundMessage(sender: "+1", body: "x")) == .pass)
}
