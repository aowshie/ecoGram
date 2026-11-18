import Foundation
import Postbox
import AyuSettings
import AyuHistory

enum AyuHistoryCapture {
    static func captureDeleted(transaction: Transaction, mediaBox: MediaBox, globalIds: [Int32]) {
        guard AyuSettings.shared.saveDeletedMessages, !globalIds.isEmpty else {
            return
        }
        self.captureDeleted(transaction: transaction, mediaBox: mediaBox, ids: transaction.messageIdsForGlobalIds(globalIds))
    }

    static func captureDeleted(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId]) {
        guard AyuSettings.shared.saveDeletedMessages, !ids.isEmpty else {
            return
        }
        let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
        let now = Int32(Date().timeIntervalSince1970)
        var records: [AyuHistoryRecord] = []
        for id in ids {
            guard let message = transaction.getMessage(id), self.isEligible(message: message, transaction: transaction) else {
                continue
            }
            let attachments = message.media.compactMap { self.attachment(media: $0, mediaBox: mediaBox, store: store) }
            if message.text.isEmpty && attachments.isEmpty {
                continue
            }
            records.append(self.record(kind: .deleted, message: message, transaction: transaction, savedAt: now, replacementText: nil, attachments: attachments))
        }
        store.append(records)
    }

    static func captureEdit(transaction: Transaction, mediaBox: MediaBox, id: MessageId, updated: StoreMessage) {
        guard AyuSettings.shared.saveEditedMessages, let message = transaction.getMessage(id), !message.text.isEmpty, message.text != updated.text, self.isEligible(message: message, transaction: transaction) else {
            return
        }
        let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
        let record = self.record(kind: .edited, message: message, transaction: transaction, savedAt: Int32(Date().timeIntervalSince1970), replacementText: updated.text, attachments: [])
        store.append([record])
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

    private static func record(kind: AyuHistoryRecord.Kind, message: Message, transaction: Transaction, savedAt: Int32, replacementText: String?, attachments: [AyuHistoryAttachment]) -> AyuHistoryRecord {
        let chatTitle = (transaction.getPeer(message.id.peerId) ?? message.peers[message.id.peerId])?.debugDisplayTitle ?? ""
        return AyuHistoryRecord(
            kind: kind,
            peerId: message.id.peerId.toInt64(),
            messageId: message.id.id,
            authorId: message.author?.id.toInt64(),
            authorName: message.author?.debugDisplayTitle ?? chatTitle,
            chatTitle: chatTitle,
            isOutgoing: !message.flags.contains(.Incoming),
            sentAt: message.timestamp,
            savedAt: savedAt,
            text: message.text,
            replacementText: replacementText,
            attachments: attachments
        )
    }

    private static func attachment(media: Media, mediaBox: MediaBox, store: AyuHistoryStore) -> AyuHistoryAttachment? {
        if let image = media as? TelegramMediaImage {
            guard let representation = largestImageRepresentation(image.representations) else {
                return AyuHistoryAttachment(kind: .photo, storedName: nil, originalName: nil, size: 0)
            }
            return self.stored(kind: .photo, resource: representation.resource, pathExtension: "jpg", originalName: nil, mediaBox: mediaBox, store: store)
        }
        if let file = media as? TelegramMediaFile {
            let kind: AyuHistoryAttachment.Kind
            if file.isInstantVideo {
                kind = .roundVideo
            } else if file.isVoice {
                kind = .voice
            } else if file.isSticker {
                kind = .sticker
            } else if file.isAnimated {
                kind = .animation
            } else if file.isVideo {
                kind = .video
            } else if file.isMusic {
                kind = .audio
            } else {
                kind = .file
            }
            return self.stored(kind: kind, resource: file.resource, pathExtension: self.pathExtension(file: file, kind: kind), originalName: file.fileName, mediaBox: mediaBox, store: store)
        }
        return AyuHistoryAttachment(kind: .other, storedName: nil, originalName: nil, size: 0)
    }

    private static func stored(kind: AyuHistoryAttachment.Kind, resource: MediaResource, pathExtension: String, originalName: String?, mediaBox: MediaBox, store: AyuHistoryStore) -> AyuHistoryAttachment {
        guard let path = mediaBox.completedResourcePath(resource) else {
            return AyuHistoryAttachment(kind: kind, storedName: nil, originalName: originalName, size: 0)
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let storedName = store.importMedia(path: path, size: size, pathExtension: pathExtension)
        return AyuHistoryAttachment(kind: kind, storedName: storedName, originalName: originalName, size: size)
    }

    private static func pathExtension(file: TelegramMediaFile, kind: AyuHistoryAttachment.Kind) -> String {
        if let fileName = file.fileName {
            let value = (fileName as NSString).pathExtension
            if !value.isEmpty {
                return value.lowercased()
            }
        }
        switch file.mimeType {
        case "application/x-tgsticker":
            return "tgs"
        case "image/webp":
            return "webp"
        case "video/webm":
            return "webm"
        case "audio/ogg":
            return "ogg"
        default:
            break
        }
        switch kind {
        case .video, .roundVideo, .animation:
            return "mp4"
        case .voice:
            return "ogg"
        case .audio:
            return "mp3"
        default:
            return ""
        }
    }
}
