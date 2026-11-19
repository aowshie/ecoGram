import Foundation
import Postbox
import AyuSettings
import AyuHistory

struct AyuRetention {
    static let empty = AyuRetention(keptIds: [], retained: [], protectedMediaIds: [])

    let keptIds: Set<MessageId>
    let retained: [StoreMessage]
    let protectedMediaIds: Set<MediaId>

    private var retainedIds: Set<MessageId> {
        var result = Set<MessageId>()
        for message in self.retained {
            if case let .Id(id) = message.id {
                result.insert(id)
            }
        }
        return result
    }

    func isDeletable(_ id: MessageId) -> Bool {
        return !self.keptIds.contains(id)
    }

    func isDeletable(globalId: Int32) -> Bool {
        return !self.keptIds.contains(where: { $0.id == globalId })
    }

    func isReported(_ id: MessageId) -> Bool {
        return !self.keptIds.contains(id) && !self.retainedIds.contains(id)
    }

    func isReported(globalId: Int32) -> Bool {
        return !self.keptIds.contains(where: { $0.id == globalId }) && !self.retainedIds.contains(where: { $0.id == globalId })
    }

    func protects(_ media: Media) -> Bool {
        guard let id = media.id else {
            return false
        }
        return self.protectedMediaIds.contains(id)
    }

    func restore(transaction: Transaction) {
        if !self.retained.isEmpty {
            let _ = transaction.addMessages(self.retained, location: .Random)
        }
    }
}

enum AyuHistoryCapture {
    static func retain(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId], isExpired: Bool = false) -> AyuRetention {
        guard !ids.isEmpty else {
            return .empty
        }
        let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
        self.expireIfNeeded(transaction: transaction, mediaBox: mediaBox, store: store)
        var keptIds = Set<MessageId>()
        for id in ids {
            if transaction.getMessage(id)?.ayuIsDeleted == true {
                keptIds.insert(id)
            }
        }
        guard AyuSettings.shared.saveDeletedMessages else {
            return AyuRetention(keptIds: keptIds, retained: [], protectedMediaIds: [])
        }
        let now = Int32(Date().timeIntervalSince1970)
        let mediaLimit = AyuSettings.shared.historyMediaLimitBytes
        var records: [AyuHistoryRecord] = []
        var retained: [StoreMessage] = []
        var protectedMediaIds = Set<MediaId>()
        for id in ids where !keptIds.contains(id) {
            guard let message = transaction.getMessage(id), self.isEligible(message: message, transaction: transaction) else {
                continue
            }
            if message.text.isEmpty && message.media.isEmpty {
                continue
            }
            records.append(AyuHistoryRecord(kind: .deleted, peerId: id.peerId.toInt64(), messageId: id.id, sentAt: message.timestamp, savedAt: now, text: message.text, replacementText: nil))
            retained.append(self.retainedMessage(message, deletedAt: now, isExpired: isExpired))
            for media in message.media {
                if let mediaId = media.id, mediaLimit > 0, self.size(of: media, mediaBox: mediaBox) <= mediaLimit {
                    protectedMediaIds.insert(mediaId)
                }
            }
        }
        store.append(records)
        return AyuRetention(keptIds: keptIds, retained: retained, protectedMediaIds: protectedMediaIds)
    }

    static func captureEdit(transaction: Transaction, mediaBox: MediaBox, id: MessageId, updated: StoreMessage) {
        guard AyuSettings.shared.saveEditedMessages, let message = transaction.getMessage(id), !message.ayuIsDeleted, !message.text.isEmpty, message.text != updated.text, self.isEligible(message: message, transaction: transaction) else {
            return
        }
        let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
        store.append([AyuHistoryRecord(kind: .edited, peerId: id.peerId.toInt64(), messageId: id.id, sentAt: message.timestamp, savedAt: Int32(Date().timeIntervalSince1970), text: message.text, replacementText: updated.text)])
    }

    static func keepSelfDestructing(transaction: Transaction, mediaBox: MediaBox, message: Message, isRemove: Bool) -> Bool {
        guard message.ayuRevealsSelfDestructingMedia, message.id.namespace == Namespaces.Message.Cloud else {
            return false
        }
        if isRemove {
            let retention = self.retain(transaction: transaction, mediaBox: mediaBox, ids: [message.id], isExpired: true)
            guard !retention.retained.isEmpty else {
                return false
            }
            _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: [message.id])
            retention.restore(transaction: transaction)
            return true
        }
        let timeout = message.attributes.compactMap({ ($0 as? AutoclearTimeoutMessageAttribute)?.timeout ?? ($0 as? AutoremoveTimeoutMessageAttribute)?.timeout }).first ?? 0
        self.expireSelfDestructing(transaction: transaction, mediaBox: mediaBox, message: message, timeout: timeout)
        return true
    }

    static func addSelfDestructSpoiler(attributes: inout [MessageAttribute], peerId: PeerId, isOutgoing: Bool = false) {
        guard AyuSettings.shared.saveSelfDestructing, !isOutgoing, peerId.namespace != Namespaces.Peer.SecretChat else {
            return
        }
        if !attributes.contains(where: { $0 is MediaSpoilerMessageAttribute }) {
            attributes.append(MediaSpoilerMessageAttribute())
        }
    }

    static func deleteUnlessKept(transaction: Transaction, mediaBox: MediaBox, id: MessageId) {
        if transaction.getMessage(id)?.ayuIsDeleted == true {
            return
        }
        _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: [id])
    }

    static func isKept(transaction: Transaction, id: MessageId) -> Bool {
        return transaction.getMessage(id)?.ayuIsDeleted == true
    }

    private static func expireIfNeeded(transaction: Transaction, mediaBox: MediaBox, store: AyuHistoryStore) {
        let expired = store.takeExpiredRecords()
        guard !expired.isEmpty else {
            return
        }
        let ids = expired.filter { $0.kind == .deleted || $0.kind == .expired }.map { record in
            MessageId(peerId: PeerId(record.peerId), namespace: Namespaces.Message.Cloud, id: record.messageId)
        }
        self.releaseKept(transaction: transaction, mediaBox: mediaBox, ids: ids)
    }

    private static func retainedMessage(_ message: Message, deletedAt: Int32, isExpired: Bool) -> StoreMessage {
        var attributes = message.attributes.filter { attribute in
            return !(attribute is AutoremoveTimeoutMessageAttribute) && !(attribute is AutoclearTimeoutMessageAttribute)
        }
        attributes.append(AyuDeletedMessageAttribute(date: deletedAt, isExpired: isExpired))
        if message.ayuIsViewOnce || message.containsSecretMedia, !attributes.contains(where: { $0 is MediaSpoilerMessageAttribute }) {
            attributes.append(MediaSpoilerMessageAttribute())
        }
        var flags = StoreMessageFlags(message.flags)
        flags.remove(.TopIndexable)
        flags.remove(.ReactionsArePossible)
        return StoreMessage(
            id: message.id,
            customStableId: message.stableId,
            globallyUniqueId: message.globallyUniqueId,
            groupingKey: message.groupingKey,
            threadId: message.threadId,
            timestamp: message.timestamp,
            flags: flags,
            tags: [],
            globalTags: [],
            localTags: [],
            forwardInfo: message.forwardInfo.map(StoreMessageForwardInfo.init),
            authorId: message.author?.id,
            text: message.text,
            attributes: attributes,
            media: message.media
        )
    }

    private static func isEligible(message: Message, transaction: Transaction) -> Bool {
        if message.id.namespace != Namespaces.Message.Cloud || message.id.peerId.namespace == Namespaces.Peer.SecretChat {
            return false
        }
        if message.media.contains(where: { $0 is TelegramMediaAction }) {
            return false
        }
        if !AyuSettings.shared.saveInBots, let user = transaction.getPeer(message.id.peerId) as? TelegramUser, user.botInfo != nil {
            return false
        }
        return true
    }

    private static func size(of media: Media, mediaBox: MediaBox) -> Int64 {
        if let file = media as? TelegramMediaFile {
            if let size = file.size {
                return size
            }
            return self.completedSize(file.resource, mediaBox: mediaBox)
        }
        if let image = media as? TelegramMediaImage {
            return image.representations.reduce(Int64(0)) { result, representation in
                return max(result, self.completedSize(representation.resource, mediaBox: mediaBox))
            }
        }
        return 0
    }

    private static func completedSize(_ resource: MediaResource, mediaBox: MediaBox) -> Int64 {
        guard let path = mediaBox.completedResourcePath(resource) else {
            return 0
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }
}
