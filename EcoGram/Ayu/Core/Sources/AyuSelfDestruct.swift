import Foundation
import Postbox
import SwiftSignalKit
import AyuSettings

public final class AyuExpiredMediaAttribute: MessageAttribute {
    public let timeout: Int32

    public init(timeout: Int32) {
        self.timeout = timeout
    }

    public init(decoder: PostboxDecoder) {
        self.timeout = decoder.decodeInt32ForKey("t", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timeout, forKey: "t")
    }
}

public extension Message {
    var ayuSelfDestructTimeout: Int32? {
        guard self.ayuRevealsSelfDestructingMedia, !self.ayuIsDeleted, self.ayuHasDestructibleMedia else {
            return nil
        }
        for attribute in self.attributes {
            if let attribute = attribute as? AutoclearTimeoutMessageAttribute {
                return attribute.timeout
            }
        }
        return nil
    }

    var ayuIsMediaExpired: Bool {
        return self.attributes.contains(where: { $0 is AyuExpiredMediaAttribute })
    }

    var ayuOpensStandalone: Bool {
        return self.ayuIsDeleted || self.ayuIsMediaExpired || self.ayuSelfDestructTimeout != nil
    }

    fileprivate var ayuHasDestructibleMedia: Bool {
        return self.media.contains(where: { $0 is TelegramMediaImage || $0 is TelegramMediaFile })
    }
}

public extension TelegramEngine.Messages {
    func ayuMarkSelfDestructViewed(id: EngineMessage.Id) -> Signal<Never, NoError> {
        return self.account.postbox.transaction { transaction -> Void in
            guard let message = transaction.getMessage(id), message.flags.contains(.Incoming), let timeout = message.ayuSelfDestructTimeout else {
                return
            }
            AyuHistoryCapture.expireSelfDestructing(transaction: transaction, message: message, timeout: timeout)
            if message.id.peerId.namespace == Namespaces.Peer.CloudUser || message.id.peerId.namespace == Namespaces.Peer.CloudGroup {
                addSynchronizeConsumeMessageContentsOperation(transaction: transaction, messageIds: [id])
            }
        }
        |> ignoreValues
    }
}

extension AyuHistoryCapture {
    static func expireSelfDestructing(transaction: Transaction, message: Message, timeout: Int32) {
        transaction.updateMessage(message.id, update: { currentMessage in
            var attributes: [MessageAttribute] = currentMessage.attributes.compactMap { attribute -> MessageAttribute? in
                if attribute is AutoremoveTimeoutMessageAttribute || attribute is AutoclearTimeoutMessageAttribute || attribute is AyuExpiredMediaAttribute {
                    return nil
                }
                if let attribute = attribute as? ConsumableContentMessageAttribute, !attribute.consumed {
                    return ConsumableContentMessageAttribute(consumed: true)
                }
                return attribute
            }
            attributes.append(AyuExpiredMediaAttribute(timeout: timeout))
            if !attributes.contains(where: { $0 is MediaSpoilerMessageAttribute }) {
                attributes.append(MediaSpoilerMessageAttribute())
            }
            return .update(StoreMessage(
                id: currentMessage.id,
                customStableId: nil,
                globallyUniqueId: currentMessage.globallyUniqueId,
                groupingKey: currentMessage.groupingKey,
                threadId: currentMessage.threadId,
                timestamp: currentMessage.timestamp,
                flags: StoreMessageFlags(currentMessage.flags),
                tags: currentMessage.tags,
                globalTags: currentMessage.globalTags,
                localTags: currentMessage.localTags,
                forwardInfo: currentMessage.forwardInfo.map(StoreMessageForwardInfo.init),
                authorId: currentMessage.author?.id,
                text: currentMessage.text,
                attributes: attributes,
                media: currentMessage.media
            ))
        })
    }

    static func preserveSelfDestructing(transaction: Transaction, id: MessageId, updated: StoreMessage) -> StoreMessage {
        guard let current = transaction.getMessage(id), current.ayuIsMediaExpired || current.ayuSelfDestructTimeout != nil, updated.media.contains(where: { $0 is TelegramMediaExpiredContent }) else {
            return updated
        }
        let timeout = current.ayuSelfDestructTimeout ?? current.attributes.compactMap({ ($0 as? AyuExpiredMediaAttribute)?.timeout }).first ?? 0
        var attributes = updated.attributes.filter { attribute in
            return !(attribute is AutoremoveTimeoutMessageAttribute) && !(attribute is AutoclearTimeoutMessageAttribute) && !(attribute is AyuExpiredMediaAttribute)
        }
        attributes.append(AyuExpiredMediaAttribute(timeout: timeout))
        if !attributes.contains(where: { $0 is MediaSpoilerMessageAttribute }) {
            attributes.append(MediaSpoilerMessageAttribute())
        }
        return StoreMessage(
            id: id,
            customStableId: nil,
            globallyUniqueId: updated.globallyUniqueId,
            groupingKey: updated.groupingKey,
            threadId: updated.threadId,
            timestamp: updated.timestamp,
            flags: updated.flags,
            tags: current.tags,
            globalTags: current.globalTags,
            localTags: updated.localTags,
            forwardInfo: updated.forwardInfo,
            authorId: updated.authorId,
            text: updated.text,
            attributes: attributes,
            media: current.media
        )
    }
}
