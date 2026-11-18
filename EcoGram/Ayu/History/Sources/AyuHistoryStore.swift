import Foundation
import AyuSettings

public final class AyuHistoryStore {
    private static let registryLock = NSLock()
    private static var registry: [String: AyuHistoryStore] = [:]

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
    private let chatsUrl: URL
    private let mediaUrl: URL
    private let queue = DispatchQueue(label: "ecogram.ayu.history", qos: .utility)
    private let fileManager = FileManager()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init(rootUrl: URL) {
        self.rootUrl = rootUrl
        self.chatsUrl = rootUrl.appendingPathComponent("chats", isDirectory: true)
        self.mediaUrl = rootUrl.appendingPathComponent("media", isDirectory: true)
        try? self.fileManager.createDirectory(at: self.chatsUrl, withIntermediateDirectories: true)
        try? self.fileManager.createDirectory(at: self.mediaUrl, withIntermediateDirectories: true)
        self.queue.async {
            self.performCleanup()
        }
    }

    public func url(storedName: String) -> URL {
        return self.mediaUrl.appendingPathComponent(storedName)
    }

    public func importMedia(path: String, size: Int64, pathExtension: String) -> String? {
        let limit = AyuSettings.shared.historyMediaLimitBytes
        guard limit > 0, size > 0, size <= limit else {
            return nil
        }
        let name = UUID().uuidString + (pathExtension.isEmpty ? "" : "." + pathExtension)
        let target = self.url(storedName: name)
        do {
            try self.fileManager.linkItem(atPath: path, toPath: target.path)
            return name
        } catch {
            do {
                try self.fileManager.copyItem(atPath: path, toPath: target.path)
                return name
            } catch {
                return nil
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
            }
        }
    }

    public func summaries(completion: @escaping ([AyuHistoryChatSummary]) -> Void) {
        self.queue.async {
            var result: [AyuHistoryChatSummary] = []
            for peerId in self.storedPeerIds() {
                let records = self.readRecords(peerId: peerId)
                guard let last = records.max(by: { $0.savedAt < $1.savedAt }) else {
                    continue
                }
                let deleted = records.filter { $0.kind == .deleted }.count
                result.append(AyuHistoryChatSummary(peerId: peerId, chatTitle: last.chatTitle, deletedCount: deleted, editedCount: records.count - deleted, lastSavedAt: last.savedAt))
            }
            result.sort(by: { $0.lastSavedAt > $1.lastSavedAt })
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    public func records(peerId: Int64, completion: @escaping ([AyuHistoryRecord]) -> Void) {
        self.queue.async {
            let records = self.readRecords(peerId: peerId).sorted(by: { $0.savedAt > $1.savedAt })
            DispatchQueue.main.async {
                completion(records)
            }
        }
    }

    public func remove(recordIds: Set<String>, peerId: Int64, completion: (() -> Void)? = nil) {
        self.queue.async {
            let records = self.readRecords(peerId: peerId)
            let removed = records.filter { recordIds.contains($0.id) }
            self.deleteMedia(of: removed)
            self.writeRecords(records.filter { !recordIds.contains($0.id) }, peerId: peerId)
            self.finish(completion)
        }
    }

    public func clear(peerId: Int64, completion: (() -> Void)? = nil) {
        self.queue.async {
            self.deleteMedia(of: self.readRecords(peerId: peerId))
            try? self.fileManager.removeItem(at: self.chatUrl(peerId: peerId))
            self.finish(completion)
        }
    }

    public func clearAll(completion: (() -> Void)? = nil) {
        self.queue.async {
            try? self.fileManager.removeItem(at: self.chatsUrl)
            try? self.fileManager.removeItem(at: self.mediaUrl)
            try? self.fileManager.createDirectory(at: self.chatsUrl, withIntermediateDirectories: true)
            try? self.fileManager.createDirectory(at: self.mediaUrl, withIntermediateDirectories: true)
            self.finish(completion)
        }
    }

    public func usage(completion: @escaping (Int64) -> Void) {
        self.queue.async {
            var total: Int64 = 0
            for directory in [self.chatsUrl, self.mediaUrl] {
                let names = (try? self.fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
                for name in names {
                    let attributes = try? self.fileManager.attributesOfItem(atPath: directory.appendingPathComponent(name).path)
                    total += (attributes?[.size] as? NSNumber)?.int64Value ?? 0
                }
            }
            DispatchQueue.main.async {
                completion(total)
            }
        }
    }

    public func cleanup() {
        self.queue.async {
            self.performCleanup()
        }
    }

    private func performCleanup() {
        let days = AyuSettings.shared.historyCleanupDays
        guard days > 0 else {
            return
        }
        let threshold = Int32(Date().timeIntervalSince1970) - Int32(days * 24 * 60 * 60)
        for peerId in self.storedPeerIds() {
            let records = self.readRecords(peerId: peerId)
            let expired = records.filter { $0.savedAt < threshold }
            guard !expired.isEmpty else {
                continue
            }
            self.deleteMedia(of: expired)
            self.writeRecords(records.filter { $0.savedAt >= threshold }, peerId: peerId)
        }
    }

    private func finish(_ completion: (() -> Void)?) {
        guard let completion else {
            return
        }
        DispatchQueue.main.async {
            completion()
        }
    }

    private func chatUrl(peerId: Int64) -> URL {
        return self.chatsUrl.appendingPathComponent("\(peerId).jsonl")
    }

    private func storedPeerIds() -> [Int64] {
        let names = (try? self.fileManager.contentsOfDirectory(atPath: self.chatsUrl.path)) ?? []
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

    private func deleteMedia(of records: [AyuHistoryRecord]) {
        for record in records {
            for attachment in record.attachments {
                if let storedName = attachment.storedName {
                    try? self.fileManager.removeItem(at: self.url(storedName: storedName))
                }
            }
        }
    }
}
