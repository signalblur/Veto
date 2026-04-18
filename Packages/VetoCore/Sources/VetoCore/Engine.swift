import Foundation

public struct Engine: Sendable {
    public let detectors: [any Detector]

    public init(detectors: [any Detector]) {
        self.detectors = detectors
    }

    public func classify(_ msg: InboundMessage, settings: Settings) async -> Decision {
        guard settings.masterEnabled else { return .none }
        for d in detectors {
            switch await d.evaluate(msg) {
            case .explicitAllow(let r):
                return .allow(reason: r)
            case .match(let id, let c) where c >= settings.threshold:
                return .junk(ruleId: id, confidence: c)
            default:
                continue
            }
        }
        return .none
    }
}
