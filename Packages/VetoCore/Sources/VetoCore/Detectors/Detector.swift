import Foundation

public protocol Detector: Sendable {
    func evaluate(_ msg: InboundMessage) async -> DetectionResult
}
