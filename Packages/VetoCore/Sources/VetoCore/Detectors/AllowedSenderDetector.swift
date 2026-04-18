import Foundation

public struct AllowedSenderDetector: Detector {
    public let trustedSenders: Set<String>

    public init(trustedSenders: Set<String>) {
        self.trustedSenders = trustedSenders
    }

    public func evaluate(_ msg: InboundMessage) async -> DetectionResult {
        if trustedSenders.contains(msg.sender) {
            return .explicitAllow(reason: .trustedSender)
        }
        return .pass
    }
}
