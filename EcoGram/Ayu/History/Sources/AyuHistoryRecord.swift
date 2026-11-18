import Foundation

public struct AyuHistoryAttachment: Codable, Equatable {
    public enum Kind: String, Codable {
        case photo
        case video
        case roundVideo
        case voice
        case audio
        case sticker
        case animation
        case file
        case other
    }

    public let kind: Kind
    public let storedName: String?
    public let originalName: String?
    public let size: Int64

    public init(kind: Kind, storedName: String?, originalName: String?, size: Int64) {
        self.kind = kind
        self.storedName = storedName
        self.originalName = originalName
        self.size = size
    }
}

public struct AyuHistoryRecord: Codable, Equatable {
    public enum Kind: String, Codable {
        case deleted
        case edited
    }

    public let id: String
    public let kind: Kind
    public let peerId: Int64
    public let messageId: Int32
    public let authorId: Int64?
    public let authorName: String
    public let chatTitle: String
    public let isOutgoing: Bool
    public let sentAt: Int32
    public let savedAt: Int32
    public let text: String
    public let replacementText: String?
    public let attachments: [AyuHistoryAttachment]

    public init(kind: Kind, peerId: Int64, messageId: Int32, authorId: Int64?, authorName: String, chatTitle: String, isOutgoing: Bool, sentAt: Int32, savedAt: Int32, text: String, replacementText: String?, attachments: [AyuHistoryAttachment]) {
        self.id = UUID().uuidString
        self.kind = kind
        self.peerId = peerId
        self.messageId = messageId
        self.authorId = authorId
        self.authorName = authorName
        self.chatTitle = chatTitle
        self.isOutgoing = isOutgoing
        self.sentAt = sentAt
        self.savedAt = savedAt
        self.text = text
        self.replacementText = replacementText
        self.attachments = attachments
    }
}

public struct AyuHistoryChatSummary: Equatable {
    public let peerId: Int64
    public let chatTitle: String
    public let deletedCount: Int
    public let editedCount: Int
    public let lastSavedAt: Int32

    public var totalCount: Int {
        return self.deletedCount + self.editedCount
    }
}
