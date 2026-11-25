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

func ayuKeptResourceIds(_ message: Message) -> [MediaResourceId] {
    var resourceIds: [MediaResourceId] = []
    for media in message.media {
        if let file = media as? TelegramMediaFile, file.isSticker || file.isAnimatedSticker || file.isVideoSticker || file.isCustomEmoji {
            continue
        }
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    }
    return resourceIds
}

func ayuKeptMediaEntries(_ message: Message, kind: AyuMediaKind) -> [AyuMediaEntry] {
    return ayuKeptResourceIds(message).map { AyuMediaEntry(kind: kind, resourceId: $0.stringRepresentation) }
}

public extension TelegramEngine.Messages {
    func ayuKeptStorage() -> Signal<AyuKeptStorage, NoError> {
        return ayuComputeKeptStorage(mediaBox: self.account.postbox.mediaBox)
    }

    func ayuKeptStorageUpdates() -> Signal<AyuKeptStorage, NoError> {
        let mediaBox = self.account.postbox.mediaBox
        let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
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
            return ayuComputeKeptStorage(mediaBox: mediaBox)
        }
        |> distinctUntilChanged
    }

    func ayuClearKept(categories: Set<AyuKeptCategory>) -> Signal<Float, NoError> {
        let postbox = self.account.postbox
        return ayuKeptRecords(mediaBox: postbox.mediaBox)
        |> mapToSignal { records -> Signal<Float, NoError> in
            return ayuRelease(postbox: postbox, records: records, categories: categories, editsThreshold: nil, clearsIndex: true)
        }
    }

    func ayuExpireKept(olderThan threshold: Int32) -> Signal<Never, NoError> {
        let postbox = self.account.postbox
        return ayuKeptRecords(mediaBox: postbox.mediaBox)
        |> mapToSignal { records -> Signal<Float, NoError> in
            return ayuRelease(postbox: postbox, records: records.filter { $0.record.savedAt < threshold }, categories: Set(AyuKeptCategory.allCases), editsThreshold: threshold, clearsIndex: false)
        }
        |> ignoreValues
    }
}

private func ayuComputeKeptStorage(mediaBox: MediaBox) -> Signal<AyuKeptStorage, NoError> {
    let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
    return Signal { subscriber in
        Queue.concurrentDefaultQueue().async {
            let usage = store.diskUsage()
            var deleted = Set<String>()
            var expired = Set<String>()
            for entry in usage.media {
                switch entry.kind {
                case .deleted:
                    deleted.insert(entry.resourceId)
                case .expired:
                    expired.insert(entry.resourceId)
                }
            }
            subscriber.putNext(AyuKeptStorage(sizes: [
                .messages: usage.keptBytes,
                .media: ayuResourcesSize(deleted, mediaBox: mediaBox),
                .disappearing: ayuResourcesSize(expired, mediaBox: mediaBox),
                .edits: usage.editsBytes
            ]))
            subscriber.putCompletion()
        }
        return EmptyDisposable
    }
}

private func ayuResourcesSize(_ resourceIds: Set<String>, mediaBox: MediaBox) -> Int64 {
    return resourceIds.reduce(Int64(0)) { result, id in
        return result + mediaBox.resourceUsage(id: MediaResourceId(id))
    }
}

private final class AyuReleaseResult {
    var recordIds = Set<String>()
    var resourceIds = Set<MediaResourceId>()
}

private func ayuRelease(postbox: Postbox, records: [AyuStoredRecord], categories: Set<AyuKeptCategory>, editsThreshold: Int32?, clearsIndex: Bool) -> Signal<Float, NoError> {
    let mediaBox = postbox.mediaBox
    let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
    let result = AyuReleaseResult()
    let releasesMessages = categories.contains(.messages)
    let releasesDisappearing = categories.contains(.disappearing)
    let keptRecords = (releasesMessages || releasesDisappearing) ? records.filter { $0.record.kind != .edited } : []
    let chunkSize = 300
    let chunkCount = (keptRecords.count + chunkSize - 1) / chunkSize

    var releaseSignal: Signal<Float, NoError> = .complete()
    for chunkIndex in 0 ..< chunkCount {
        let chunk = Array(keptRecords[chunkIndex * chunkSize ..< min((chunkIndex + 1) * chunkSize, keptRecords.count)])
        let step = postbox.transaction { transaction -> Float in
            var releasedIds: [MessageId] = []
            for stored in chunk {
                let record = stored.record
                let id = MessageId(peerId: PeerId(record.peerId), namespace: Namespaces.Message.Cloud, id: record.messageId)
                let message = transaction.getMessage(id)
                let isMessage = record.kind == .deleted && message?.ayuDeletedAttribute?.isExpired != true
                guard isMessage ? releasesMessages : releasesDisappearing else {
                    continue
                }
                releasedIds.append(id)
                result.recordIds.insert(record.id)
                if let message {
                    result.resourceIds.formUnion(ayuKeptResourceIds(message))
                }
            }
            AyuHistoryCapture.releaseKept(transaction: transaction, mediaBox: mediaBox, ids: releasedIds)
            return Float(chunkIndex + 1) / Float(chunkCount) * 0.5
        }
        releaseSignal = releaseSignal |> then(step)
    }

    var indexKinds = Set<AyuMediaKind>()
    if clearsIndex {
        if releasesMessages || categories.contains(.media) {
            indexKinds.insert(.deleted)
        }
        if releasesDisappearing {
            indexKinds.insert(.expired)
        }
    }

    let finish: Signal<Float, NoError> = deferred {
        var resourceIds = result.resourceIds
        for entry in store.diskUsage().media where indexKinds.contains(entry.kind) {
            resourceIds.insert(MediaResourceId(entry.resourceId))
        }
        let recordIds = result.recordIds
        let resourceStrings = Set(resourceIds.map(\.stringRepresentation))
        let removeRecords = Signal<Never, NoError> { subscriber in
            store.remove(ids: recordIds, completion: {
                store.removeMedia(kinds: indexKinds, resourceIds: resourceStrings, completion: {
                    if categories.contains(.edits) {
                        store.removeEdits(olderThan: editsThreshold, completion: {
                            subscriber.putCompletion()
                        })
                    } else {
                        NotificationCenter.default.post(name: AyuHistoryStore.didRemove, object: store)
                        subscriber.putCompletion()
                    }
                })
            })
            return EmptyDisposable
        }
        let removeResources: Signal<Float, NoError> = resourceIds.isEmpty ? .single(1.0) : (mediaBox.removeCachedResources(Array(resourceIds), force: true) |> map { 0.5 + $0 * 0.5 })
        return (removeRecords |> map { _ -> Float in }) |> then(removeResources)
    }
    return releaseSignal |> then(finish)
}

private func ayuKeptRecords(mediaBox: MediaBox) -> Signal<[AyuStoredRecord], NoError> {
    let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
    return Signal { subscriber in
        store.loadKept(completion: { records in
            subscriber.putNext(records)
            subscriber.putCompletion()
        })
        return EmptyDisposable
    }
}
