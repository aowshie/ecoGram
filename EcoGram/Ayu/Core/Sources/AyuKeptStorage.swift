import Foundation
import Postbox
import SwiftSignalKit
import AyuHistory

public enum AyuKeptCategory: Hashable, CaseIterable {
    case messages
    case media
    case disappearing
    case edits
}

public struct AyuKeptStorage: Equatable {
    public let sizes: [AyuKeptCategory: Int64]

    public var total: Int64 {
        return self.sizes.values.reduce(0, +)
    }
}

private struct AyuKeptIndex {
    var messageIds: [MessageId] = []
    var messageRecordIds = Set<String>()
    var messageBytes: Int64 = 0
    var mediaResources = Set<MediaResourceId>()
    var disappearingIds: [MessageId] = []
    var disappearingRecordIds = Set<String>()
    var disappearingResources = Set<MediaResourceId>()
    var disappearingBytes: Int64 = 0

    init(transaction: Transaction, records: [AyuStoredRecord]) {
        for stored in records {
            let record = stored.record
            let recordBytes = stored.size
            switch record.kind {
            case .edited:
                break
            case .deleted, .expired:
                let id = MessageId(peerId: PeerId(record.peerId), namespace: Namespaces.Message.Cloud, id: record.messageId)
                let message = transaction.getMessage(id)
                if record.kind == .deleted, message?.ayuDeletedAttribute?.isExpired != true {
                    self.messageIds.append(id)
                    self.messageRecordIds.insert(record.id)
                    self.messageBytes += recordBytes
                    if let message {
                        self.messageBytes += Int64(message.text.utf8.count)
                        self.mediaResources.formUnion(ayuKeptResourceIds(message))
                    }
                } else {
                    self.disappearingIds.append(id)
                    self.disappearingRecordIds.insert(record.id)
                    self.disappearingBytes += recordBytes
                    if let message, message.ayuIsDeleted || message.ayuIsMediaExpired {
                        self.disappearingResources.formUnion(ayuKeptResourceIds(message))
                    }
                }
            }
        }
    }
}

private func ayuKeptResourceIds(_ message: Message) -> [MediaResourceId] {
    var resourceIds: [MediaResourceId] = []
    for media in message.media {
        if let file = media as? TelegramMediaFile, file.isSticker || file.isAnimatedSticker || file.isVideoSticker || file.isCustomEmoji {
            continue
        }
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    }
    return resourceIds
}

private func ayuResourcesSize(_ resourceIds: Set<MediaResourceId>, mediaBox: MediaBox) -> Int64 {
    return resourceIds.reduce(Int64(0)) { result, id in
        return result + mediaBox.resourceUsage(id: id)
    }
}

public extension TelegramEngine.Messages {
    func ayuKeptStorage() -> Signal<AyuKeptStorage, NoError> {
        return ayuComputeKeptStorage(postbox: self.account.postbox)
    }

    func ayuKeptStorageUpdates() -> Signal<AyuKeptStorage, NoError> {
        let postbox = self.account.postbox
        let store = AyuHistoryStore.store(mediaBoxBasePath: postbox.mediaBox.basePath)
        let changes = Signal<Void, NoError> { subscriber in
            subscriber.putNext(Void())
            let observer = NotificationCenter.default.addObserver(forName: AyuHistoryStore.didRemove, object: store, queue: nil, using: { _ in
                subscriber.putNext(Void())
            })
            return ActionDisposable {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        return changes
        |> mapToSignal { _ -> Signal<AyuKeptStorage, NoError> in
            return ayuComputeKeptStorage(postbox: postbox)
        }
        |> distinctUntilChanged
    }

    func ayuClearKept(categories: Set<AyuKeptCategory>) -> Signal<Float, NoError> {
        let postbox = self.account.postbox
        return ayuHistoryRecords(mediaBox: postbox.mediaBox)
        |> mapToSignal { records, _ -> Signal<Float, NoError> in
            return ayuRelease(postbox: postbox, records: records, categories: categories, editsThreshold: nil)
        }
    }

    func ayuExpireKept(olderThan threshold: Int32) -> Signal<Never, NoError> {
        let postbox = self.account.postbox
        return ayuHistoryRecords(mediaBox: postbox.mediaBox)
        |> mapToSignal { records, _ -> Signal<Float, NoError> in
            return ayuRelease(postbox: postbox, records: records.filter { $0.record.savedAt < threshold }, categories: Set(AyuKeptCategory.allCases), editsThreshold: threshold)
        }
        |> ignoreValues
    }
}

private func ayuComputeKeptStorage(postbox: Postbox) -> Signal<AyuKeptStorage, NoError> {
    let mediaBox = postbox.mediaBox
    return ayuHistoryRecords(mediaBox: mediaBox)
    |> mapToSignal { records, editsSize -> Signal<(AyuKeptIndex, Int64), NoError> in
        return postbox.transaction { transaction -> (AyuKeptIndex, Int64) in
            return (AyuKeptIndex(transaction: transaction, records: records), editsSize)
        }
    }
    |> deliverOn(Queue.concurrentDefaultQueue())
    |> map { index, editsSize -> AyuKeptStorage in
        return AyuKeptStorage(sizes: [
            .messages: index.messageBytes,
            .media: ayuResourcesSize(index.mediaResources, mediaBox: mediaBox),
            .disappearing: index.disappearingBytes + ayuResourcesSize(index.disappearingResources, mediaBox: mediaBox),
            .edits: editsSize
        ])
    }
}

private func ayuRelease(postbox: Postbox, records: [AyuStoredRecord], categories: Set<AyuKeptCategory>, editsThreshold: Int32?) -> Signal<Float, NoError> {
    let mediaBox = postbox.mediaBox
    let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
    return postbox.transaction { transaction -> (Set<String>, Set<MediaResourceId>) in
        let index = AyuKeptIndex(transaction: transaction, records: records)
        var releasedIds: [MessageId] = []
        var recordIds = Set<String>()
        var resourceIds = Set<MediaResourceId>()
        if categories.contains(.messages) {
            releasedIds.append(contentsOf: index.messageIds)
            recordIds.formUnion(index.messageRecordIds)
            resourceIds.formUnion(index.mediaResources)
        } else if categories.contains(.media) {
            resourceIds.formUnion(index.mediaResources)
        }
        if categories.contains(.disappearing) {
            releasedIds.append(contentsOf: index.disappearingIds)
            recordIds.formUnion(index.disappearingRecordIds)
            resourceIds.formUnion(index.disappearingResources)
        }
        AyuHistoryCapture.releaseKept(transaction: transaction, mediaBox: mediaBox, ids: releasedIds)
        return (recordIds, resourceIds)
    }
    |> mapToSignal { recordIds, resourceIds -> Signal<Float, NoError> in
        let removeRecords = Signal<Never, NoError> { subscriber in
            store.remove(ids: recordIds, completion: {
                if categories.contains(.edits) {
                    store.removeEdits(olderThan: editsThreshold, completion: {
                        subscriber.putCompletion()
                    })
                } else {
                    subscriber.putCompletion()
                }
            })
            return EmptyDisposable
        }
        let removeResources: Signal<Float, NoError> = resourceIds.isEmpty ? .single(1.0) : mediaBox.removeCachedResources(Array(resourceIds), force: true)
        return (removeRecords |> map { _ -> Float in }) |> then(removeResources)
    }
}

private func ayuHistoryRecords(mediaBox: MediaBox) -> Signal<([AyuStoredRecord], Int64), NoError> {
    let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
    return Signal { subscriber in
        store.loadKept(completion: { records, editsSize in
            subscriber.putNext((records, editsSize))
            subscriber.putCompletion()
        })
        return EmptyDisposable
    }
}
