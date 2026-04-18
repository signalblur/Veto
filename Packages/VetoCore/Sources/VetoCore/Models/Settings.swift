import Foundation

public struct Settings: Sendable, Equatable {
    public var masterEnabled: Bool
    public var threshold: Double
    public var enabledPacks: Set<String>
    public var smartDetection: SmartDetectionSettings

    public init(
        masterEnabled: Bool,
        threshold: Double,
        enabledPacks: Set<String> = ["donations"],
        smartDetection: SmartDetectionSettings = SmartDetectionSettings()
    ) {
        self.masterEnabled = masterEnabled
        self.threshold = threshold
        self.enabledPacks = enabledPacks
        self.smartDetection = smartDetection
    }
}

public struct SmartDetectionSettings: Sendable, Codable, Equatable {
    public var coreMLEnabled: Bool
    public var foundationModelsEnabled: Bool

    public init(coreMLEnabled: Bool = false, foundationModelsEnabled: Bool = false) {
        self.coreMLEnabled = coreMLEnabled
        self.foundationModelsEnabled = foundationModelsEnabled
    }
}

extension Settings: Codable {
    private enum CodingKeys: String, CodingKey {
        case masterEnabled, threshold, enabledPacks, smartDetection
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.masterEnabled = try container.decode(Bool.self, forKey: .masterEnabled)
        self.threshold = try container.decode(Double.self, forKey: .threshold)
        self.enabledPacks = try container.decodeIfPresent(Set<String>.self, forKey: .enabledPacks) ?? ["donations"]
        self.smartDetection = try container.decodeIfPresent(SmartDetectionSettings.self, forKey: .smartDetection) ?? SmartDetectionSettings()
    }
}
