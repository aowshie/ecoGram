import Foundation

public final class AyuHistoryStore {
    public static let didRemove = Notification.Name("ecogram.ayu.historyDidRemove")

    private static let registryLock = NSLock()
    private static var registry: [String: AyuHistoryStore] = [:]
    private static let newline = UInt8(ascii: "\n")
    private static let keptSuffix = ".jsonl"
    private static let editsSuffix = ".edits.jsonl"
    private static let layoutMarker = "layout.v2"

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
            self.splitEditsIfNeeded()
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
                let edits = items.filter { $0.kind == .edited }
                let kept = items.filter { $0.kind != .edited }
                if !kept.isEmpty {
                    self.appendLines(kept, url: self.keptUrl(peerId: peerId))
                }
                if !edits.isEmpty {
                    self.appendLines(edits, url: self.editsUrl(peerId: peerId))
                    self.indexLock.lock()
                    self.editedMessageIds[peerId, default: []].formUnion(edits.map(\.messageId))
                    self.indexLock.unlock()
                }
            }
        }
    }

    public func loadKept(completion: @escaping ([AyuStoredRecord], Int64) -> Void) {
        self.queue.async {
            let records = self.storedPeerIds(suffix: AyuHistoryStore.keptSuffix).flatMap { self.readStoredRecords(url: self.keptUrl(peerId: $0), decoder: self.decoder) }
            let editsSize = self.storedPeerIds(suffix: AyuHistoryStore.editsSuffix).reduce(Int64(0)) { result, peerId in
                return result + self.fileSize(self.editsUrl(peerId: peerId))
            }
            completion(records, editsSize)
        }
    }

    public func remove(ids: Set<String>, completion: @escaping () -> Void) {
        guard !ids.isEmpty else {
            completion()
            return
        }
        self.queue.async {
            for peerId in self.storedPeerIds(suffix: AyuHistoryStore.keptSuffix) {
                let url = self.keptUrl(peerId: peerId)
                let records = self.readStoredRecords(url: url, decoder: self.decoder).map(\.record)
                let kept = records.filter { !ids.contains($0.id) }
                if kept.count != records.count {
                    self.writeRecords(kept, url: url)
                }
            }
            NotificationCenter.default.post(name: AyuHistoryStore.didRemove, object: self)
            completion()
        }
    }

    public func removeEdits(olderThan threshold: Int32?, completion: @escaping () -> Void) {
        self.queue.async {
            for peerId in self.storedPeerIds(suffix: AyuHistoryStore.editsSuffix) {
                let url = self.editsUrl(peerId: peerId)
                var kept: [AyuHistoryRecord] = []
                if let threshold {
                    let records = self.readStoredRecords(url: url, decoder: self.decoder).map(\.record)
                    kept = records.filter { $0.savedAt >= threshold }
                    if kept.count == records.count {
                        continue
                    }
                }
                self.writeRecords(kept, url: url)
                let messageIds = Set(kept.map(\.messageId))
                self.indexLock.lock()
                self.editedMessageIds[peerId] = messageIds.isEmpty ? nil : messageIds
                self.indexLock.unlock()
            }
            NotificationCenter.default.post(name: AyuHistoryStore.didRemove, object: self)
            completion()
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

    private func splitEditsIfNeeded() {
        let marker = self.rootUrl.appendingPathComponent(AyuHistoryStore.layoutMarker)
        guard !self.fileManager.fileExists(atPath: marker.path) else {
            return
        }
        for peerId in self.storedPeerIds(suffix: AyuHistoryStore.keptSuffix) {
            let url = self.keptUrl(peerId: peerId)
            let records = self.readStoredRecords(url: url, decoder: self.decoder).map(\.record)
            let edits = records.filter { $0.kind == .edited }
            guard !edits.isEmpty else {
                continue
            }
            self.appendLines(edits, url: self.editsUrl(peerId: peerId))
            self.writeRecords(records.filter { $0.kind != .edited }, url: url)
        }
        self.fileManager.createFile(atPath: marker.path, contents: Data())
    }

    private func keptUrl(peerId: Int64) -> URL {
        return self.rootUrl.appendingPathComponent("\(peerId)\(AyuHistoryStore.keptSuffix)")
    }

    private func editsUrl(peerId: Int64) -> URL {
        return self.rootUrl.appendingPathComponent("\(peerId)\(AyuHistoryStore.editsSuffix)")
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

    private func fileSize(_ url: URL) -> Int64 {
        let attributes = try? self.fileManager.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func readStoredRecords(url: URL, decoder: JSONDecoder) -> [AyuStoredRecord] {
        guard let data = try? Data(contentsOf: url) else {
            return []
        }
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
        var data = self.encodedLines(records)
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
