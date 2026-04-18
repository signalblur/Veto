import Foundation

public struct FoundationModelsDetector: Detector {
    public typealias DonationAskProvider = @Sendable (String) async -> Bool?

    private let provider: DonationAskProvider

    public init(provider: @escaping DonationAskProvider) {
        self.provider = provider
    }

    public func evaluate(_ msg: InboundMessage) async -> DetectionResult {
        guard let isPoliticalDonationAsk = await provider(msg.body), isPoliticalDonationAsk else {
            return .pass
        }
        return .match(ruleId: "ml.foundation-models", confidence: 1.0)
    }
}
