import Foundation

public final class AyuHistoryStore {
    public static let didRemove = Notification.Name("ecogram.ayu.historyDidRemove")

    private static let registryLock = NSLock()
    private static var registry: [String: AyuHistoryStore] = [:]
    private static let newline = UInt8(ascii: "\n")
    private static let keptSuffix = ".jsonl"
    private static let expiredSuffix = ".expired.jsonl"
    private static let editsSuffix = ".edits.jsonl"
    private static let legacyLayoutMarker = "layout.v2"
    private static let layoutMarker = "layout.v3"
    private static let mediaIndexName = "media.idx"
    private static let tab = UInt8(ascii: "\t")

    private static func mediaLine(_ entry: AyuMediaEntry) -> Data {
        var data = Data(entry.kind.rawValue.utf8)
        data.append(AyuHistoryStore.tab)
        data.append(contentsOf: Array(entry.resourceId.utf8))
        data.append(AyuHistoryStore.newline)
        return data
    }

    public static func store(mediaBoxBasePath: String) -> AyuHistoryStore {
        let accountUrl = URL(fileURLWithPath: mediaBoxBasePath).deletingLastPathComponent().deletingLastPathComponent()
        let rootUrl = accountUrl.appendingPathComponent("ecogram-history", isDirectory: true)
        self.registryLock.lock()
        defer {
            self.registryLock.unlock()
        }
        if let current = self.registry[rootUrl.path] {
            return current
        }
        let store = AyuHistoryStore(rootUrl: rootUrl)
        self.registry[rootUrl.path] = store
        return store
    }

    private let rootUrl: URL
    private let queue = DispatchQueue(label: "ecogram.ayu.history", qos: .utility)
    private let indexQueue = DispatchQueue(label: "ecogram.ayu.history.index", qos: .utility)
    private let fileManager = FileManager()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let indexLock = NSLock()
    private var editedMessageIds: [Int64: Set<Int32>] = [:]

    private init(rootUrl: URL) {
        self.rootUrl = rootUrl
        self.queue.async {
            try? self.fileManager.createDirectory(at: rootUrl, withIntermediateDirectories: true)
            self.splitKindsIfNeeded()
            let peerIds = self.storedPeerIds(suffix: AyuHistoryStore.editsSuffix)
            self.indexQueue.async {
                let decoder = JSONDecoder()
                for peerId in peerIds {
                    let messageIds = Set(self.readStoredRecords(url: self.editsUrl(peerId: peerId), decoder: decoder).map(\.record.messageId))
                    self.indexLock.lock()
                    self.editedMessageIds[peerId, default: []].formUnion(messageIds)
                    self.indexLock.unlock()
                }
            }
        }
    }

    public func append(_ records: [AyuHistoryRecord]) {
        guard !records.isEmpty else {
            return
        }
        self.queue.async {
            for (peerId, items) in Dictionary(grouping: records, by: { $0.peerId }) {
                for (kind, kindItems) in Dictionary(grouping: items, by: { $0.kind }) {
                    self.appendLines(kindItems, url: self.url(peerId: peerId, kind: kind))
                }
                let edits = items.filter { $0.kind == .edited }
                if !edits.isEmpty {
                    self.indexLock.lock()
                    self.editedMessageIds[peerId, default: []].formUnion(edits.map(\.messageId))
                    self.indexLock.unlock()
                }
            }
        }
    }

    public func appendMedia(_ entries: [AyuMediaEntry]) {
        guard !entries.isEmpty else {
            return
        }
        var data = Data()
        for entry in entries {
            data.append(AyuHistoryStore.mediaLine(entry))
        }
        self.queue.async {
            self.appendData(data, url: self.mediaIndexUrl)
        }
    }

    public func diskUsage() -> AyuDiskUsage {
        let fileManager = FileManager()
        let names = (try? fileManager.contentsOfDirectory(atPath: self.rootUrl.path)) ?? []
        var recordBytes: [Int64: [AyuHistoryRecord.Kind: Int64]] = [:]
        for name in names {
            guard let parsed = AyuHistoryStore.parse(fileName: name) else {
                continue
            }
            recordBytes[parsed.peerId, default: [:]][parsed.kind, default: 0] += self.fileSize(self.rootUrl.appendingPathComponent(name), fileManager: fileManager)
        }
        return AyuDiskUsage(recordBytes: recordBytes, media: self.readMediaIndex())
    }

    public func removeMedia(kinds: Set<AyuMediaKind>, entries removing: [AyuMediaEntry], completion: @escaping (_ removed: [AyuMediaEntry], _ remaining: [AyuMediaEntry]) -> Void) {
        self.queue.async {
            var pending: [AyuMediaEntry: Int] = [:]
            for entry in removing {
                pending[entry, default: 0] += 1
            }
            var removed: [AyuMediaEntry] = []
            var kept: [AyuMediaEntry] = []
            for entry in self.readMediaIndex() {
                if kinds.contains(entry.kind) {
                    removed.append(entry)
                } else if let count = pending[entry], count > 0 {
                    pending[entry] = count - 1
                    removed.append(entry)
                } else {
                    kept.append(entry)
                }
            }
            if !removed.isEmpty {
                if kept.isEmpty {
                    try? self.fileManager.removeItem(at: self.mediaIndexUrl)
                } else {
                    var data = Data()
                    for entry in kept {
                        data.append(AyuHistoryStore.mediaLine(entry))
                    }
                    try? data.write(to: self.mediaIndexUrl, options: .atomic)
                }
            }
            completion(removed, kept)
        }
    }

    public func loadKept(completion: @escaping ([AyuStoredRecord]) -> Void) {
        self.queue.async {
            completion(self.keptUrls().flatMap { self.readStoredRecords(url: $0, decoder: self.decoder) })
        }
    }

    public func remove(ids: Set<String>, completion: @escaping () -> Void) {
        guard !ids.isEmpty else {
            completion()
            return
        }
        self.queue.async {
            for url in self.keptUrls() {
                guard let records = self.readRecords(url: url) else {
                    continue
                }
                let kept = records.filter { !ids.contains($0.id) }
                if kept.isEmpty || kept.count != records.count {
                    self.writeRecords(kept, url: url)
                }
            }
            completion()
        }
    }

    public func records(peerId: Int64) -> [AyuHistoryRecord] {
        let urls = [AyuHistoryRecord.Kind.deleted, .expired, .edited].map { self.url(peerId: peerId, kind: $0) }
        guard urls.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return []
        }
        return self.queue.sync {
            return urls.flatMap { self.readStoredRecords(url: $0, decoder: self.decoder).map(\.record) }
        }
    }

    public func forget(peerId: Int64, messageIds: Set<Int32>?, completion: @escaping (_ isChanged: Bool) -> Void) {
        if let messageIds, messageIds.isEmpty {
            completion(false)
            return
        }
        self.queue.async {
            var isChanged = false
            for kind in [AyuHistoryRecord.Kind.deleted, .expired, .edited] {
                let url = self.url(peerId: peerId, kind: kind)
                guard let records = self.readRecords(url: url) else {
                    continue
                }
                let kept = messageIds.map { messageIds in records.filter { !messageIds.contains($0.messageId) } } ?? []
                if !kept.isEmpty && kept.count == records.count {
                    continue
                }
                self.writeRecords(kept, url: url)
                isChanged = true
                if kind == .edited {
                    let editedIds = Set(kept.map(\.messageId))
                    self.indexLock.lock()
                    self.editedMessageIds[peerId] = editedIds.isEmpty ? nil : editedIds
                    self.indexLock.unlock()
                }
            }
            completion(isChanged)
        }
    }

    public func removeEdits(olderThan threshold: Int32?, peerIds: Set<Int64>?, completion: @escaping () -> Void) {
        self.queue.async {
            let storedPeerIds = self.storedPeerIds(suffix: AyuHistoryStore.editsSuffix).filter { peerIds?.contains($0) ?? true }
            self.rewriteEdits(peerIds: storedPeerIds, isKept: { record in
                guard let threshold else {
                    return false
                }
                return record.savedAt >= threshold
            })
            completion()
        }
    }

    public func removeEdits(messageIds: [Int64: Set<Int32>], completion: @escaping () -> Void) {
        guard !messageIds.isEmpty else {
            completion()
            return
        }
        self.queue.async {
            let peerIds = self.storedPeerIds(suffix: AyuHistoryStore.editsSuffix).filter { messageIds[$0] != nil }
            self.rewriteEdits(peerIds: peerIds, isKept: { record in
                return !(messageIds[record.peerId]?.contains(record.messageId) ?? false)
            })
            completion()
        }
    }

    private func rewriteEdits(peerIds: [Int64], isKept: (AyuHistoryRecord) -> Bool) {
        for peerId in peerIds {
            let url = self.editsUrl(peerId: peerId)
            guard let records = self.readRecords(url: url) else {
                continue
            }
            let kept = records.filter(isKept)
            if !kept.isEmpty && kept.count == records.count {
                continue
            }
            self.writeRecords(kept, url: url)
            let messageIds = Set(kept.map(\.messageId))
            self.indexLock.lock()
            self.editedMessageIds[peerId] = messageIds.isEmpty ? nil : messageIds
            self.indexLock.unlock()
        }
    }

    public func hasEditRecords(peerId: Int64, messageId: Int32) -> Bool {
        self.indexLock.lock()
        defer {
            self.indexLock.unlock()
        }
        return self.editedMessageIds[peerId]?.contains(messageId) ?? false
    }

    public func loadEditRecords(peerId: Int64, messageId: Int32, completion: @escaping ([AyuHistoryRecord]) -> Void) {
        self.queue.async {
            let records = self.readStoredRecords(url: self.editsUrl(peerId: peerId), decoder: self.decoder).map(\.record).filter { $0.messageId == messageId }.sorted(by: { $0.savedAt < $1.savedAt })
            DispatchQueue.main.async {
                completion(records)
            }
        }
    }

    private func splitKindsIfNeeded() {
        let marker = self.rootUrl.appendingPathComponent(AyuHistoryStore.layoutMarker)
        guard !self.fileManager.fileExists(atPath: marker.path) else {
            return
        }
        for peerId in self.storedPeerIds(suffix: AyuHistoryStore.keptSuffix) {
            let url = self.url(peerId: peerId, kind: .deleted)
            let records = self.readStoredRecords(url: url, decoder: self.decoder).map(\.record)
            let moved = records.filter { $0.kind != .deleted }
            guard !moved.isEmpty else {
                continue
            }
            for (kind, items) in Dictionary(grouping: moved, by: { $0.kind }) {
                self.appendLines(items, url: self.url(peerId: peerId, kind: kind))
            }
            self.writeRecords(records.filter { $0.kind == .deleted }, url: url)
        }
        try? self.fileManager.removeItem(at: self.rootUrl.appendingPathComponent(AyuHistoryStore.legacyLayoutMarker))
        self.fileManager.createFile(atPath: marker.path, contents: Data())
    }

    private static func suffix(kind: AyuHistoryRecord.Kind) -> String {
        switch kind {
        case .deleted:
            return AyuHistoryStore.keptSuffix
        case .expired:
            return AyuHistoryStore.expiredSuffix
        case .edited:
            return AyuHistoryStore.editsSuffix
        }
    }

    private static func parse(fileName: String) -> (peerId: Int64, kind: AyuHistoryRecord.Kind)? {
        for kind in [AyuHistoryRecord.Kind.edited, .expired, .deleted] {
            let suffix = AyuHistoryStore.suffix(kind: kind)
            if fileName.hasSuffix(suffix), let peerId = Int64(fileName.dropLast(suffix.count)) {
                return (peerId, kind)
            }
        }
        return nil
    }

    private func url(peerId: Int64, kind: AyuHistoryRecord.Kind) -> URL {
        return self.rootUrl.appendingPathComponent("\(peerId)\(AyuHistoryStore.suffix(kind: kind))")
    }

    private func editsUrl(peerId: Int64) -> URL {
        return self.url(peerId: peerId, kind: .edited)
    }

    private func keptUrls() -> [URL] {
        let deleted = self.storedPeerIds(suffix: AyuHistoryStore.keptSuffix).map { self.url(peerId: $0, kind: .deleted) }
        let expired = self.storedPeerIds(suffix: AyuHistoryStore.expiredSuffix).map { self.url(peerId: $0, kind: .expired) }
        return deleted + expired
    }

    private func storedPeerIds(suffix: String) -> [Int64] {
        let names = (try? self.fileManager.contentsOfDirectory(atPath: self.rootUrl.path)) ?? []
        return names.compactMap { name -> Int64? in
            guard name.hasSuffix(suffix) else {
                return nil
            }
            return Int64(name.dropLast(suffix.count))
        }
    }

    private var mediaIndexUrl: URL {
        return self.rootUrl.appendingPathComponent(AyuHistoryStore.mediaIndexName)
    }

    private func fileSize(_ url: URL, fileManager: FileManager) -> Int64 {
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func readMediaIndex() -> [AyuMediaEntry] {
        guard let data = try? Data(contentsOf: self.mediaIndexUrl) else {
            return []
        }
        return data.split(separator: AyuHistoryStore.newline).compactMap { line -> AyuMediaEntry? in
            let parts = line.split(separator: AyuHistoryStore.tab, maxSplits: 1)
            guard parts.count == 2, let kind = AyuMediaKind(rawValue: String(decoding: parts[0], as: UTF8.self)) else {
                return nil
            }
            return AyuMediaEntry(kind: kind, resourceId: String(decoding: parts[1], as: UTF8.self))
        }
    }

    private func readRecords(url: URL) -> [AyuHistoryRecord]? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return self.decodeRecords(data, decoder: self.decoder).map(\.record)
    }

    private func readStoredRecords(url: URL, decoder: JSONDecoder) -> [AyuStoredRecord] {
        guard let data = try? Data(contentsOf: url) else {
            return []
        }
        return self.decodeRecords(data, decoder: decoder)
    }

    private func decodeRecords(_ data: Data, decoder: JSONDecoder) -> [AyuStoredRecord] {
        return data.split(separator: AyuHistoryStore.newline).compactMap { line in
            guard let record = try? decoder.decode(AyuHistoryRecord.self, from: Data(line)) else {
                return nil
            }
            return AyuStoredRecord(record: record, size: Int64(line.count + 1))
        }
    }

    private func encodedLines(_ records: [AyuHistoryRecord]) -> Data {
        var data = Data()
        for record in records {
            guard let line = try? self.encoder.encode(record) else {
                continue
            }
            data.append(line)
            data.append(AyuHistoryStore.newline)
        }
        return data
    }

    private func appendLines(_ records: [AyuHistoryRecord], url: URL) {
        self.appendData(self.encodedLines(records), url: url)
    }

    private func appendData(_ data: Data, url: URL) {
        var data = data
        guard let handle = try? FileHandle(forUpdating: url) else {
            try? data.write(to: url, options: .atomic)
            return
        }
        defer {
            try? handle.close()
        }
        do {
            let end = try handle.seekToEnd()
            if end > 0 {
                try handle.seek(toOffset: end - 1)
                if try handle.read(upToCount: 1)?.first != AyuHistoryStore.newline {
                    data.insert(AyuHistoryStore.newline, at: 0)
                }
            }
            try handle.write(contentsOf: data)
        } catch {
            return
        }
    }

    private func writeRecords(_ records: [AyuHistoryRecord], url: URL) {
        if records.isEmpty {
            try? self.fileManager.removeItem(at: url)
        } else {
            try? self.encodedLines(records).write(to: url, options: .atomic)
        }
    }
}

public struct AyuStoredRecord {
    public let record: AyuHistoryRecord
    public let size: Int64
}

public enum AyuMediaKind: String {
    case deleted = "d"
    case expired = "e"
}

public struct AyuMediaEntry: Hashable {
    public let kind: AyuMediaKind
    public let resourceId: String

    public init(kind: AyuMediaKind, resourceId: String) {
        self.kind = kind
        self.resourceId = resourceId
    }
}

public struct AyuDiskUsage {
    public let recordBytes: [Int64: [AyuHistoryRecord.Kind: Int64]]
    public let media: [AyuMediaEntry]
}
