import Foundation

public struct Settings: Sendable, Codable, Equatable {
    public var masterEnabled: Bool
    public var threshold: Double

    public init(masterEnabled: Bool, threshold: Double) {
        self.masterEnabled = masterEnabled
        self.threshold = threshold
    }
}
