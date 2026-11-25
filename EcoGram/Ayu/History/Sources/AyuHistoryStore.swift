import Foundation

public final class AyuHistoryStore {
    public static let didRemove = Notification.Name("ecogram.ayu.historyDidRemove")

    private static let registryLock = NSLock()
    private static var registry: [String: AyuHistoryStore] = [:]
    private static let newline = UInt8(ascii: "\n")

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
    private let fileManager = FileManager()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let indexLock = NSLock()
    private var editedMessageIds: [Int64: Set<Int32>] = [:]

    private init(rootUrl: URL) {
        self.rootUrl = rootUrl
        self.queue.async {
            try? self.fileManager.createDirectory(at: rootUrl, withIntermediateDirectories: true)
            for peerId in self.storedPeerIds() {
                self.updateEditIndex(peerId: peerId, records: self.readRecords(peerId: peerId))
            }
        }
    }

    public func append(_ records: [AyuHistoryRecord]) {
        guard !records.isEmpty else {
            return
        }
        self.queue.async {
            let grouped = Dictionary(grouping: records, by: { $0.peerId })
            for (peerId, items) in grouped {
                self.appendLines(items, peerId: peerId)
                let editedIds = items.filter { $0.kind == .edited }.map(\.messageId)
                if !editedIds.isEmpty {
                    self.indexLock.lock()
                    self.editedMessageIds[peerId, default: []].formUnion(editedIds)
                    self.indexLock.unlock()
                }
            }
        }
    }

    public func load(completion: @escaping ([AyuStoredRecord]) -> Void) {
        self.queue.async {
            completion(self.storedPeerIds().flatMap { self.readStoredRecords(peerId: $0) })
        }
    }

    public func remove(ids: Set<String>, completion: @escaping () -> Void) {
        guard !ids.isEmpty else {
            completion()
            return
        }
        self.queue.async {
            for peerId in self.storedPeerIds() {
                let records = self.readRecords(peerId: peerId)
                let kept = records.filter { !ids.contains($0.id) }
                guard kept.count != records.count else {
                    continue
                }
                self.writeRecords(kept, peerId: peerId)
                self.updateEditIndex(peerId: peerId, records: kept)
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
            let records = self.readRecords(peerId: peerId).filter { $0.kind == .edited && $0.messageId == messageId }.sorted(by: { $0.savedAt < $1.savedAt })
            DispatchQueue.main.async {
                completion(records)
            }
        }
    }

    private func updateEditIndex(peerId: Int64, records: [AyuHistoryRecord]) {
        let editedIds = Set(records.filter { $0.kind == .edited }.map(\.messageId))
        self.indexLock.lock()
        self.editedMessageIds[peerId] = editedIds.isEmpty ? nil : editedIds
        self.indexLock.unlock()
    }

    private func chatUrl(peerId: Int64) -> URL {
        return self.rootUrl.appendingPathComponent("\(peerId).jsonl")
    }

    private func storedPeerIds() -> [Int64] {
        let names = (try? self.fileManager.contentsOfDirectory(atPath: self.rootUrl.path)) ?? []
        return names.compactMap { name -> Int64? in
            guard name.hasSuffix(".jsonl") else {
                return nil
            }
            return Int64(name.dropLast(".jsonl".count))
        }
    }

    private func readRecords(peerId: Int64) -> [AyuHistoryRecord] {
        return self.readStoredRecords(peerId: peerId).map(\.record)
    }

    private func readStoredRecords(peerId: Int64) -> [AyuStoredRecord] {
        guard let data = try? Data(contentsOf: self.chatUrl(peerId: peerId)) else {
            return []
        }
        return data.split(separator: AyuHistoryStore.newline).compactMap { line in
            guard let record = try? self.decoder.decode(AyuHistoryRecord.self, from: Data(line)) else {
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

    private func appendLines(_ records: [AyuHistoryRecord], peerId: Int64) {
        let url = self.chatUrl(peerId: peerId)
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

    private func writeRecords(_ records: [AyuHistoryRecord], peerId: Int64) {
        let url = self.chatUrl(peerId: peerId)
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
