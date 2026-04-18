import Foundation

public struct CoreMLDetector: Detector {
    public typealias ConfidenceProvider = @Sendable (String) async -> Double?

    public let confidenceThreshold: Double
    private let provider: ConfidenceProvider

    public init(confidenceThreshold: Double = 0.85, provider: @escaping ConfidenceProvider) {
        self.confidenceThreshold = confidenceThreshold
        self.provider = provider
    }

    public func evaluate(_ msg: InboundMessage) async -> DetectionResult {
        guard let confidence = await provider(msg.body), confidence >= confidenceThreshold else {
            return .pass
        }
        return .match(ruleId: "ml.coreml", confidence: confidence)
    }
}
