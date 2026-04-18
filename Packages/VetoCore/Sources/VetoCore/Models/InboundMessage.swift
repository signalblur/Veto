import Foundation

public struct InboundMessage: Sendable, Equatable {
    public let sender: String
    public let body: String

    public init(sender: String, body: String) {
        self.sender = sender
        self.body = body
    }
}
