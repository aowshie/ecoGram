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

func ayuIsKeptMedia(_ media: Media) -> Bool {
    if media is TelegramMediaImage {
        return true
    }
    if let file = media as? TelegramMediaFile {
        return !(file.isSticker || file.isAnimatedSticker || file.isVideoSticker || file.isCustomEmoji)
    }
    return false
}

func ayuKeptResourceIds(_ media: Media) -> [MediaResourceId] {
    guard ayuIsKeptMedia(media) else {
        return []
    }
    var resourceIds: [MediaResourceId] = []
    addMessageMediaResourceIdsToRemove(media: media, resourceIds: &resourceIds)
    return resourceIds
}

func ayuKeptMediaEntries(_ media: Media, kind: AyuMediaKind) -> [AyuMediaEntry] {
    return ayuKeptResourceIds(media).map { AyuMediaEntry(kind: kind, resourceId: $0.stringRepresentation) }
}

func ayuKeptMediaEntries(_ message: Message, kind: AyuMediaKind) -> [AyuMediaEntry] {
    return message.media.flatMap { ayuKeptMediaEntries($0, kind: kind) }
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
                .messages: usage.recordBytes[.deleted] ?? 0,
                .media: ayuResourcesSize(deleted, mediaBox: mediaBox),
                .disappearing: (usage.recordBytes[.expired] ?? 0) + ayuResourcesSize(expired, mediaBox: mediaBox),
                .edits: usage.recordBytes[.edited] ?? 0
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
    var entries = Set<AyuMediaEntry>()
}

private struct AyuReleasePlan {
    let releasesMessages: Bool
    let stripsMedia: Bool
    let releasesDisappearing: Bool

    init(categories: Set<AyuKeptCategory>) {
        self.releasesMessages = categories.contains(.messages)
        self.stripsMedia = categories.contains(.media) && !self.releasesMessages
        self.releasesDisappearing = categories.contains(.disappearing)
    }

    func targets(_ record: AyuHistoryRecord) -> Bool {
        switch record.kind {
        case .deleted:
            return self.releasesMessages || self.stripsMedia
        case .expired:
            return self.releasesDisappearing
        case .edited:
            return false
        }
    }

    var indexKinds: Set<AyuMediaKind> {
        var kinds = Set<AyuMediaKind>()
        if self.releasesMessages || self.stripsMedia {
            kinds.insert(.deleted)
        }
        if self.releasesDisappearing {
            kinds.insert(.expired)
        }
        return kinds
    }
}

private func ayuReleaseChunk(transaction: Transaction, mediaBox: MediaBox, chunk: [AyuStoredRecord], plan: AyuReleasePlan, result: AyuReleaseResult) {
    var releasedIds: [MessageId] = []
    for stored in chunk {
        let record = stored.record
        let id = MessageId(peerId: PeerId(record.peerId), namespace: Namespaces.Message.Cloud, id: record.messageId)
        let message = transaction.getMessage(id)
        if record.kind == .deleted && plan.stripsMedia {
            guard let message, message.ayuIsDeleted, message.media.contains(where: ayuIsKeptMedia) else {
                continue
            }
            result.entries.formUnion(ayuKeptMediaEntries(message, kind: .deleted))
            if !message.text.isEmpty {
                AyuHistoryCapture.stripKeptMedia(transaction: transaction, message: message)
                continue
            }
        } else if let message {
            result.entries.formUnion(ayuKeptMediaEntries(message, kind: record.kind == .expired ? .expired : .deleted))
        }
        releasedIds.append(id)
        result.recordIds.insert(record.id)
    }
    AyuHistoryCapture.releaseKept(transaction: transaction, mediaBox: mediaBox, ids: releasedIds)
}

private func ayuRelease(postbox: Postbox, records: [AyuStoredRecord], categories: Set<AyuKeptCategory>, editsThreshold: Int32?, clearsIndex: Bool) -> Signal<Float, NoError> {
    let mediaBox = postbox.mediaBox
    let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
    let plan = AyuReleasePlan(categories: categories)
    let result = AyuReleaseResult()
    let targets = records.filter { plan.targets($0.record) }
    let chunkSize = 300
    let chunkCount = (targets.count + chunkSize - 1) / chunkSize

    var releaseSignal: Signal<Float, NoError> = .complete()
    for chunkIndex in 0 ..< chunkCount {
        let chunk = Array(targets[chunkIndex * chunkSize ..< min((chunkIndex + 1) * chunkSize, targets.count)])
        releaseSignal = releaseSignal |> then(postbox.transaction { transaction -> Float in
            ayuReleaseChunk(transaction: transaction, mediaBox: mediaBox, chunk: chunk, plan: plan, result: result)
            return Float(chunkIndex + 1) / Float(chunkCount) * 0.5
        })
    }

    let indexKinds = clearsIndex ? plan.indexKinds : []
    let removeRecords = Signal<Set<MediaResourceId>, NoError> { subscriber in
        store.remove(ids: result.recordIds, completion: {
            store.removeMedia(kinds: indexKinds, entries: result.entries, completion: { removed, remaining in
                let remainingIds = Set(remaining.map(\.resourceId))
                let releasedIds = Set(removed.map(\.resourceId)).union(result.entries.map(\.resourceId))
                let resourceIds = Set(releasedIds.subtracting(remainingIds).map { MediaResourceId($0) })
                let finish = {
                    subscriber.putNext(resourceIds)
                    subscriber.putCompletion()
                }
                if categories.contains(.edits) {
                    store.removeEdits(olderThan: editsThreshold, completion: finish)
                } else {
                    finish()
                }
            })
        })
        return EmptyDisposable
    }
    let removeResources = removeRecords
    |> mapToSignal { resourceIds -> Signal<Float, NoError> in
        if resourceIds.isEmpty {
            return .single(1.0)
        }
        return mediaBox.removeCachedResources(Array(resourceIds), force: true)
        |> map { 0.5 + $0 * 0.5 }
    }
    let notify: Signal<Float, NoError> = deferred {
        NotificationCenter.default.post(name: AyuHistoryStore.didRemove, object: store)
        return .complete()
    }
    return releaseSignal |> then(removeResources) |> then(notify)
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
