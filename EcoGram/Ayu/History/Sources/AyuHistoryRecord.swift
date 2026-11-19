import Foundation

public struct AyuHistoryRecord: Codable, Equatable {
    public enum Kind: String, Codable {
        case deleted
        case edited
        case expired
    }

    public let id: String
    public let kind: Kind
    public let peerId: Int64
    public let messageId: Int32
    public let sentAt: Int32
    public let savedAt: Int32
    public let text: String
    public let replacementText: String?

    public init(kind: Kind, peerId: Int64, messageId: Int32, sentAt: Int32, savedAt: Int32, text: String, replacementText: String?) {
        self.id = UUID().uuidString
        self.kind = kind
        self.peerId = peerId
        self.messageId = messageId
        self.sentAt = sentAt
        self.savedAt = savedAt
        self.text = text
        self.replacementText = replacementText
    }
}
