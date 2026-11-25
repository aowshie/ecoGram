import Foundation
import Postbox
internal import TelegramApi
import SwiftSignalKit
import AyuSettings
import AyuHistory

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

    var ayuSelfDestructRemaining: Int32? {
        guard let timeout = self.ayuSelfDestructTimeout, timeout != viewOnceTimeout else {
            return nil
        }
        for attribute in self.attributes {
            if let attribute = attribute as? AutoclearTimeoutMessageAttribute, let begin = attribute.countdownBeginTime, begin != 0 {
                let now = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                return max(0, begin + timeout - now)
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
        let network = self.account.network
        let stateManager: AccountStateManager = self.account.stateManager
        return self.account.postbox.transaction { transaction -> Bool in
            guard !ayuSuppressesContentRead(peerId: id.peerId), let message = transaction.getMessage(id), message.flags.contains(.Incoming), message.ayuSelfDestructTimeout != nil else {
                return false
            }
            let isStarted = message.attributes.contains(where: { (($0 as? AutoclearTimeoutMessageAttribute)?.countdownBeginTime ?? 0) != 0 })
            if isStarted {
                return false
            }
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            transaction.updateMessage(id, update: { currentMessage in
                let attributes: [MessageAttribute] = currentMessage.attributes.map { attribute -> MessageAttribute in
                    if let attribute = attribute as? ConsumableContentMessageAttribute, !attribute.consumed {
                        return ConsumableContentMessageAttribute(consumed: true)
                    }
                    if let attribute = attribute as? AutoclearTimeoutMessageAttribute {
                        return AutoclearTimeoutMessageAttribute(timeout: attribute.timeout, countdownBeginTime: timestamp)
                    }
                    return attribute
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
            return id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup
        }
        |> mapToSignal { shouldReport -> Signal<Never, NoError> in
            guard shouldReport else {
                return .complete()
            }
            return network.request(Api.functions.messages.readMessageContents(id: [id.id]))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Never, NoError> in
                if let result {
                    switch result {
                    case let .affectedMessages(affectedMessagesData):
                        stateManager.addUpdateGroups([.updatePts(pts: affectedMessagesData.pts, ptsCount: affectedMessagesData.ptsCount)])
                    }
                }
                return .complete()
            }
        }
    }
}

extension AyuHistoryCapture {
    static func releaseKept(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId]) {
        var deleted: [MessageId] = []
        var resourceIds: [MediaResourceId] = []
        for id in ids {
            guard let message = transaction.getMessage(id) else {
                continue
            }
            if message.ayuIsDeleted {
                deleted.append(id)
            } else if message.ayuIsMediaExpired {
                for media in message.media {
                    addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
                }
                self.restoreExpiredContent(transaction: transaction, message: message)
            }
        }
        if !deleted.isEmpty {
            _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: deleted)
        }
        if !resourceIds.isEmpty {
            let _ = mediaBox.removeCachedResources(Array(Set(resourceIds)), force: true).start()
        }
    }

    private static func expiredContentData(_ media: [Media]) -> TelegramMediaExpiredContentData {
        for item in media {
            if let file = item as? TelegramMediaFile {
                if file.isVoice {
                    return .voiceMessage
                }
                if file.isInstantVideo {
                    return .videoMessage
                }
                return .file
            }
        }
        return .image
    }

    private static func restoreExpiredContent(transaction: Transaction, message: Message) {
        let data = self.expiredContentData(message.media)
        transaction.updateMessage(message.id, update: { currentMessage in
            let attributes = currentMessage.attributes.filter { attribute in
                return !(attribute is AyuExpiredMediaAttribute) && !(attribute is MediaSpoilerMessageAttribute)
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
                media: [TelegramMediaExpiredContent(data: data)]
            ))
        })
    }

    static func recordExpired(mediaBox: MediaBox, message: Message) {
        let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
        store.append([AyuHistoryRecord(kind: .expired, peerId: message.id.peerId.toInt64(), messageId: message.id.id, sentAt: message.timestamp, savedAt: Int32(Date().timeIntervalSince1970), text: "", replacementText: nil)])
        store.appendMedia(ayuKeptMediaEntries(message, kind: .expired))
    }

    static func expireSelfDestructing(transaction: Transaction, mediaBox: MediaBox, message: Message, timeout: Int32) {
        if !message.ayuIsMediaExpired {
            self.recordExpired(mediaBox: mediaBox, message: message)
        }
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

    static func preserveSelfDestructing(transaction: Transaction, mediaBox: MediaBox, id: MessageId, updated: StoreMessage) -> StoreMessage {
        guard let current = transaction.getMessage(id), current.ayuIsMediaExpired || current.ayuSelfDestructTimeout != nil, updated.media.contains(where: { $0 is TelegramMediaExpiredContent }) else {
            return updated
        }
        let timeout = current.ayuSelfDestructTimeout ?? current.attributes.compactMap({ ($0 as? AyuExpiredMediaAttribute)?.timeout }).first ?? 0
        if !current.ayuIsMediaExpired {
            self.recordExpired(mediaBox: mediaBox, message: current)
        }
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
