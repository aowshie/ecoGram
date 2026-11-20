import Foundation
import UIKit
import AyuSettings

public enum AyuBadgeKind: Equatable {
    case official
    case supporter
}

public final class AyuBadges {
    public static let shared = AyuBadges()
    public static let didUpdate = Notification.Name("ecogram.ayu.badgesDidUpdate")

    private struct Snapshot: Codable {
        var developers: Set<Int64>
        var officialChannels: Set<Int64>
        var supporters: Set<Int64>
        var supporterChannels: Set<Int64>
        var fetchedAt: Double

        static let empty = Snapshot(developers: [], officialChannels: [], supporters: [], supporterChannels: [], fetchedAt: 0.0)
    }

    private static let sources: [URL] = [
        URL(string: "https://update.ayugram.one/rc/current/desktop2")!,
        URL(string: "https://api.exteragram.app/api/v1/profiles/compact")!
    ]
    private static let refreshInterval: TimeInterval = 6 * 60 * 60
    private static let retryInterval: TimeInterval = 10 * 60

    private let lock = NSLock()
    private var snapshot: Snapshot
    private var isRefreshing = false
    private var lastAttempt: TimeInterval = 0.0
    private let cacheUrl: URL
    private let session: URLSession

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheUrl = caches.appendingPathComponent("ecogram-ayu-badges.json")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20.0
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        self.session = URLSession(configuration: configuration)
        if let data = try? Data(contentsOf: self.cacheUrl), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            self.snapshot = snapshot
        } else {
            self.snapshot = .empty
        }
    }

    public func badge(id: Int64, isChannel: Bool) -> AyuBadgeKind? {
        guard AyuSettings.shared.showAyuBadges else {
            return nil
        }
        self.refreshIfNeeded()
        self.lock.lock()
        let snapshot = self.snapshot
        self.lock.unlock()
        if isChannel {
            if snapshot.officialChannels.contains(id) {
                return .official
            }
            if snapshot.supporterChannels.contains(id) {
                return .supporter
            }
        } else {
            if snapshot.developers.contains(id) {
                return .official
            }
            if snapshot.supporters.contains(id) {
                return .supporter
            }
        }
        return nil
    }

    public func refreshIfNeeded() {
        let now = Date().timeIntervalSince1970
        self.lock.lock()
        let isStale = now - self.snapshot.fetchedAt > AyuBadges.refreshInterval
        let canRetry = now - self.lastAttempt > AyuBadges.retryInterval
        guard isStale, canRetry, !self.isRefreshing else {
            self.lock.unlock()
            return
        }
        self.isRefreshing = true
        self.lastAttempt = now
        self.lock.unlock()
        self.fetch(sourceIndex: 0)
    }

    private func fetch(sourceIndex: Int) {
        guard sourceIndex < AyuBadges.sources.count else {
            self.finish(nil)
            return
        }
        let task = self.session.dataTask(with: AyuBadges.sources[sourceIndex], completionHandler: { [weak self] data, response, _ in
            guard let self else {
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let data, status == 200, let snapshot = AyuBadges.parse(data) {
                self.finish(snapshot)
            } else {
                self.fetch(sourceIndex: sourceIndex + 1)
            }
        })
        task.resume()
    }

    private func finish(_ snapshot: Snapshot?) {
        self.lock.lock()
        self.isRefreshing = false
        if let snapshot {
            self.snapshot = snapshot
        }
        self.lock.unlock()
        guard let snapshot else {
            return
        }
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: self.cacheUrl, options: .atomic)
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: AyuBadges.didUpdate, object: self)
        }
    }

    private static func parse(_ data: Data) -> Snapshot? {
        guard let object = try? JSONSerialization.jsonObject(with: data), let root = object as? [String: Any] else {
            return nil
        }
        func ids(_ key: String) -> Set<Int64> {
            guard let values = root[key] as? [Any] else {
                return []
            }
            return Set(values.compactMap { ($0 as? NSNumber)?.int64Value })
        }
        var supporters = ids("supporters")
        if let custom = root["customBadges"] as? [[String: Any]] {
            for entry in custom {
                if let id = (entry["id"] as? NSNumber)?.int64Value {
                    supporters.insert(id)
                }
            }
        }
        let snapshot = Snapshot(developers: ids("developers"), officialChannels: ids("officialChannels"), supporters: supporters, supporterChannels: ids("supporterChannels"), fetchedAt: Date().timeIntervalSince1970)
        if snapshot.developers.isEmpty && snapshot.supporters.isEmpty {
            return nil
        }
        return snapshot
    }
}
