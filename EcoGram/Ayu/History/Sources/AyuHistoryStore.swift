import Foundation
import AyuSettings

public final class AyuHistoryStore {
    private static let registryLock = NSLock()
    private static var registry: [String: AyuHistoryStore] = [:]
    private static let expirationInterval: TimeInterval = 6 * 60 * 60

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
    private var lastExpiration: TimeInterval = 0.0

    private init(rootUrl: URL) {
        self.rootUrl = rootUrl
        try? self.fileManager.createDirectory(at: rootUrl, withIntermediateDirectories: true)
    }

    public func append(_ records: [AyuHistoryRecord]) {
        guard !records.isEmpty else {
            return
        }
        self.queue.async {
            let grouped = Dictionary(grouping: records, by: { $0.peerId })
            for (peerId, items) in grouped {
                self.appendLines(items, peerId: peerId)
            }
        }
    }

    public func editRecords(peerId: Int64, messageId: Int32) -> [AyuHistoryRecord] {
        return self.queue.sync { () -> [AyuHistoryRecord] in
            return self.readRecords(peerId: peerId).filter { $0.kind == .edited && $0.messageId == messageId }.sorted(by: { $0.savedAt < $1.savedAt })
        }
    }

    public func remove(kind: AyuHistoryRecord.Kind, completion: @escaping ([AyuHistoryRecord]) -> Void) {
        self.queue.async {
            var removed: [AyuHistoryRecord] = []
            for peerId in self.storedPeerIds() {
                let records = self.readRecords(peerId: peerId)
                let matching = records.filter { $0.kind == kind }
                guard !matching.isEmpty else {
                    continue
                }
                self.writeRecords(records.filter { $0.kind != kind }, peerId: peerId)
                removed.append(contentsOf: matching)
            }
            DispatchQueue.main.async {
                completion(removed)
            }
        }
    }

    public func expire(completion: @escaping ([AyuHistoryRecord]) -> Void) {
        self.queue.async {
            let expired = self.removeExpired()
            DispatchQueue.main.async {
                completion(expired)
            }
        }
    }

    public func takeExpiredRecords() -> [AyuHistoryRecord] {
        let now = Date().timeIntervalSince1970
        return self.queue.sync { () -> [AyuHistoryRecord] in
            guard now - self.lastExpiration > AyuHistoryStore.expirationInterval else {
                return []
            }
            self.lastExpiration = now
            return self.removeExpired()
        }
    }

    private func removeExpired() -> [AyuHistoryRecord] {
        let days = AyuSettings.shared.historyCleanupDays
        guard days > 0 else {
            return []
        }
        let threshold = Int32(Date().timeIntervalSince1970) - Int32(days * 24 * 60 * 60)
        var removed: [AyuHistoryRecord] = []
        for peerId in self.storedPeerIds() {
            let records = self.readRecords(peerId: peerId)
            let expired = records.filter { $0.savedAt < threshold }
            guard !expired.isEmpty else {
                continue
            }
            self.writeRecords(records.filter { $0.savedAt >= threshold }, peerId: peerId)
            removed.append(contentsOf: expired)
        }
        return removed
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
        guard let data = try? Data(contentsOf: self.chatUrl(peerId: peerId)) else {
            return []
        }
        return data.split(separator: UInt8(ascii: "\n")).compactMap { line in
            return try? self.decoder.decode(AyuHistoryRecord.self, from: Data(line))
        }
    }

    private func encodedLines(_ records: [AyuHistoryRecord]) -> Data {
        var data = Data()
        for record in records {
            guard let line = try? self.encoder.encode(record) else {
                continue
            }
            data.append(line)
            data.append(UInt8(ascii: "\n"))
        }
        return data
    }

    private func appendLines(_ records: [AyuHistoryRecord], peerId: Int64) {
        let url = self.chatUrl(peerId: peerId)
        let data = self.encodedLines(records)
        guard let handle = try? FileHandle(forWritingTo: url) else {
            try? data.write(to: url, options: .atomic)
            return
        }
        defer {
            try? handle.close()
        }
        do {
            try handle.seekToEnd()
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
