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
    public let peers: [EnginePeer.Id: [AyuKeptCategory: Int64]]
    let peerRecordBytes: [EnginePeer.Id: Int64]
    let peerResources: [EnginePeer.Id: Set<String>]
    let resourceSizes: [String: Int64]

    public var total: Int64 {
        return self.sizes.values.reduce(0, +)
    }

    public func peer(_ peerId: EnginePeer.Id) -> AyuKeptStorage {
        return AyuKeptStorage(sizes: self.peers[peerId] ?? [:], peers: [:], peerRecordBytes: [:], peerResources: [:], resourceSizes: [:])
    }

    public func size(peerIds: Set<EnginePeer.Id>) -> Int64 {
        let recordBytes = peerIds.reduce(Int64(0)) { $0 + (self.peerRecordBytes[$1] ?? 0) }
        let resources = peerIds.reduce(into: Set<String>()) { $0.formUnion(self.peerResources[$1] ?? []) }
        return recordBytes + resources.reduce(Int64(0)) { $0 + (self.resourceSizes[$1] ?? 0) }
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
    func ayuPrepareHistory() {
        let _ = AyuHistoryStore.store(mediaBoxBasePath: self.account.postbox.mediaBox.basePath)
    }

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

    func ayuClearKept(categories: Set<AyuKeptCategory>, peerIds: Set<EnginePeer.Id>? = nil) -> Signal<Float, NoError> {
        let postbox = self.account.postbox
        let scope = peerIds.map { Set($0.map { $0.toInt64() }) }
        return ayuKeptRecords(mediaBox: postbox.mediaBox)
        |> mapToSignal { records -> Signal<Float, NoError> in
            let scoped = records.filter { scope?.contains($0.record.peerId) ?? true }
            return ayuRelease(postbox: postbox, records: scoped, categories: categories, scope: scope, editsThreshold: nil, clearsIndex: scope == nil)
        }
    }

    func ayuExpireKept(olderThan threshold: Int32) -> Signal<Never, NoError> {
        let postbox = self.account.postbox
        return ayuKeptRecords(mediaBox: postbox.mediaBox)
        |> mapToSignal { records -> Signal<Float, NoError> in
            return ayuRelease(postbox: postbox, records: records.filter { $0.record.savedAt < threshold }, categories: Set(AyuKeptCategory.allCases), scope: nil, editsThreshold: threshold, clearsIndex: false)
        }
        |> ignoreValues
    }
}

extension AyuHistoryCapture {
    static func forgetCleared(transaction: Transaction, mediaBox: MediaBox, peerId: PeerId, threadId: Int64?, timestamps: ClosedRange<Int32>?, maxId: Int32?) {
        guard peerId.namespace != Namespaces.Peer.SecretChat else {
            return
        }
        let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
        let peerIdValue = peerId.toInt64()
        let isPartial = threadId != nil || timestamps != nil || maxId != nil
        var messageIds = Set<Int32>()
        var entries: [AyuMediaEntry] = []
        for record in store.records(peerId: peerIdValue) {
            let message = transaction.getMessage(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: record.messageId))
            if let threadId, message?.threadId != threadId {
                continue
            }
            if let timestamps, !timestamps.contains(record.sentAt) {
                continue
            }
            if let maxId, record.messageId > maxId {
                continue
            }
            messageIds.insert(record.messageId)
            if let message, record.kind != .edited {
                entries.append(contentsOf: ayuKeptMediaEntries(message, kind: ayuMediaKind(record: record.kind)))
            }
        }
        if isPartial && messageIds.isEmpty {
            return
        }
        store.forget(peerId: peerIdValue, messageIds: isPartial ? messageIds : nil, completion: { isChanged in
            store.removeMedia(kinds: [], entries: entries, completion: { removed, remaining in
                let resourceIds = Set(removed.map(\.resourceId)).subtracting(remaining.map(\.resourceId)).map { MediaResourceId($0) }
                let notify = {
                    NotificationCenter.default.post(name: AyuHistoryStore.didRemove, object: store)
                }
                if !resourceIds.isEmpty {
                    let _ = mediaBox.removeCachedResources(resourceIds, force: true).startStandalone(completed: notify)
                } else if isChanged {
                    notify()
                }
            })
        })
    }
}

private func ayuCategory(record kind: AyuHistoryRecord.Kind) -> AyuKeptCategory {
    switch kind {
    case .deleted:
        return .messages
    case .expired:
        return .disappearing
    case .edited:
        return .edits
    }
}

private func ayuCategory(media kind: AyuMediaKind) -> AyuKeptCategory {
    switch kind {
    case .deleted:
        return .media
    case .expired:
        return .disappearing
    }
}

private func ayuMediaKind(record kind: AyuHistoryRecord.Kind) -> AyuMediaKind {
    return kind == .expired ? .expired : .deleted
}

private func ayuComputeKeptStorage(postbox: Postbox) -> Signal<AyuKeptStorage, NoError> {
    let mediaBox = postbox.mediaBox
    let store = AyuHistoryStore.store(mediaBoxBasePath: mediaBox.basePath)
    return ayuKeptRecords(mediaBox: mediaBox)
    |> mapToSignal { records -> Signal<[AyuMediaEntry: Set<PeerId>], NoError> in
        return postbox.transaction { transaction -> [AyuMediaEntry: Set<PeerId>] in
            var owners: [AyuMediaEntry: Set<PeerId>] = [:]
            for stored in records {
                let record = stored.record
                let peerId = PeerId(record.peerId)
                guard let message = transaction.getMessage(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: record.messageId)) else {
                    continue
                }
                for entry in ayuKeptMediaEntries(message, kind: ayuMediaKind(record: record.kind)) {
                    owners[entry, default: []].insert(peerId)
                }
            }
            return owners
        }
    }
    |> mapToSignal { owners -> Signal<AyuKeptStorage, NoError> in
        return Signal { subscriber in
            Queue.concurrentDefaultQueue().async {
                subscriber.putNext(ayuKeptStorage(usage: store.diskUsage(), owners: owners, mediaBox: mediaBox))
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
}

private func ayuKeptStorage(usage: AyuDiskUsage, owners: [AyuMediaEntry: Set<PeerId>], mediaBox: MediaBox) -> AyuKeptStorage {
    var totals: [AyuKeptCategory: Int64] = [:]
    var peers: [PeerId: [AyuKeptCategory: Int64]] = [:]
    var peerRecordBytes: [PeerId: Int64] = [:]
    for (peerIdValue, kinds) in usage.recordBytes {
        let peerId = PeerId(peerIdValue)
        for (kind, bytes) in kinds {
            let category = ayuCategory(record: kind)
            totals[category, default: 0] += bytes
            peers[peerId, default: [:]][category, default: 0] += bytes
            peerRecordBytes[peerId, default: 0] += bytes
        }
    }

    var resourceSizes: [String: Int64] = [:]
    func resourceSize(_ id: String) -> Int64 {
        if let size = resourceSizes[id] {
            return size
        }
        let size = mediaBox.resourceUsage(id: MediaResourceId(id))
        resourceSizes[id] = size
        return size
    }

    let stored = Set(usage.media)
    var storedIds: [AyuMediaKind: Set<String>] = [:]
    for entry in stored {
        storedIds[entry.kind, default: []].insert(entry.resourceId)
    }
    for (kind, ids) in storedIds {
        totals[ayuCategory(media: kind), default: 0] += ids.reduce(Int64(0)) { $0 + resourceSize($1) }
    }

    var peerIds: [PeerId: [AyuMediaKind: Set<String>]] = [:]
    for (entry, entryOwners) in owners where stored.contains(entry) {
        for peerId in entryOwners {
            peerIds[peerId, default: [:]][entry.kind, default: []].insert(entry.resourceId)
        }
    }
    var peerResources: [PeerId: Set<String>] = [:]
    for (peerId, kinds) in peerIds {
        for (kind, ids) in kinds {
            peers[peerId, default: [:]][ayuCategory(media: kind), default: 0] += ids.reduce(Int64(0)) { $0 + resourceSize($1) }
            peerResources[peerId, default: []].formUnion(ids)
        }
    }

    return AyuKeptStorage(
        sizes: totals,
        peers: peers.filter { !$0.value.values.allSatisfy { $0 == 0 } },
        peerRecordBytes: peerRecordBytes,
        peerResources: peerResources,
        resourceSizes: resourceSizes
    )
}

private final class AyuReleaseResult {
    var recordIds = Set<String>()
    var entries: [AyuMediaEntry] = []
    var deletedMessageIds: [Int64: Set<Int32>] = [:]
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
            result.entries.append(contentsOf: ayuKeptMediaEntries(message, kind: .deleted))
            if !message.text.isEmpty {
                AyuHistoryCapture.stripKeptMedia(transaction: transaction, message: message)
                continue
            }
        } else if let message {
            result.entries.append(contentsOf: ayuKeptMediaEntries(message, kind: ayuMediaKind(record: record.kind)))
        }
        releasedIds.append(id)
        result.recordIds.insert(record.id)
        if message?.ayuIsDeleted ?? true {
            result.deletedMessageIds[record.peerId, default: []].insert(record.messageId)
        }
    }
    AyuHistoryCapture.releaseKept(transaction: transaction, mediaBox: mediaBox, ids: releasedIds)
}

private func ayuRelease(postbox: Postbox, records: [AyuStoredRecord], categories: Set<AyuKeptCategory>, scope: Set<Int64>?, editsThreshold: Int32?, clearsIndex: Bool) -> Signal<Float, NoError> {
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
                store.removeEdits(messageIds: result.deletedMessageIds, completion: {
                    if categories.contains(.edits) {
                        store.removeEdits(olderThan: editsThreshold, peerIds: scope, completion: finish)
                    } else {
                        finish()
                    }
                })
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
