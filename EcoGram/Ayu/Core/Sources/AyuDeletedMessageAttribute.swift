import Foundation
import Postbox
import SwiftSignalKit
import AyuSettings

public final class AyuDeletedMessageAttribute: MessageAttribute {
    public let date: Int32
    public let isExpired: Bool

    public init(date: Int32, isExpired: Bool) {
        self.date = date
        self.isExpired = isExpired
    }

    public init(decoder: PostboxDecoder) {
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
        self.isExpired = decoder.decodeBoolForKey("e", orElse: false)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.date, forKey: "d")
        encoder.encodeBool(self.isExpired, forKey: "e")
    }
}

public extension Message {
    var ayuDeletedAttribute: AyuDeletedMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? AyuDeletedMessageAttribute {
                return attribute
            }
        }
        return nil
    }

    var ayuIsDeleted: Bool {
        return self.ayuDeletedAttribute != nil
    }

    var ayuIsViewOnce: Bool {
        return self.attributes.contains(where: { attribute in
            if let attribute = attribute as? AutoclearTimeoutMessageAttribute {
                return attribute.timeout == viewOnceTimeout
            }
            if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                return attribute.timeout == viewOnceTimeout
            }
            return false
        })
    }

    var ayuRevealsSelfDestructingMedia: Bool {
        return AyuSettings.shared.keepsSelfDestructingMedia && self.flags.contains(.Incoming) && self.id.peerId.namespace != Namespaces.Peer.SecretChat
    }
}

public extension TelegramEngine.Messages {
    func ayuDeleteKeptMessages(ids: [EngineMessage.Id]) -> Signal<Never, NoError> {
        let mediaBox = self.account.postbox.mediaBox
        return self.account.postbox.transaction { transaction -> Void in
            AyuHistoryCapture.releaseKept(transaction: transaction, mediaBox: mediaBox, ids: ids)
        }
        |> ignoreValues
    }
}
