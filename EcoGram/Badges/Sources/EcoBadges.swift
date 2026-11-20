import Foundation
import EcoPreferences

public enum EcoBadgeKind: Equatable {
    case developer
    case early
    case official
}

public final class EcoBadges {
    public static let shared = EcoBadges()

    private struct Snapshot: Codable {
        var developers: Set<Int64>
        var early: Set<Int64>
        var officialChannels: Set<Int64>
        var earlyOpen: Bool
        var fetchedAt: Double

        static let empty = Snapshot(developers: [], early: [], officialChannels: [], earlyOpen: true, fetchedAt: 0.0)
    }

    private static let badgesUrl = URL(string: "https://api.ecogram.cc/v1/badges")!
    private static let earlyUrl = URL(string: "https://api.ecogram.cc/v1/early")!
    private static let refreshInterval: TimeInterval = 60 * 60
    private static let retryInterval: TimeInterval = 10 * 60
    private static let earlyClaimSettledKey = "ecogram.earlyBadge.settled"

    private let lock = NSLock()
    private var snapshot: Snapshot
    private var isRefreshing = false
    private var isClaiming = false
    private var lastAttempt: TimeInterval = 0.0
    private let cacheUrl: URL
    private let session: URLSession
    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheUrl = caches.appendingPathComponent("ecogram-badges.json")
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

    public func badge(id: Int64, isChannel: Bool) -> EcoBadgeKind? {
        guard EcoPreferences.shared.showEcoBadges else {
            return nil
        }
        self.refreshIfNeeded()
        self.lock.lock()
        let snapshot = self.snapshot
        self.lock.unlock()
        if isChannel {
            return snapshot.officialChannels.contains(id) ? .official : nil
        }
        if snapshot.developers.contains(id) {
            return .developer
        }
        if snapshot.early.contains(id) {
            return .early
        }
        return nil
    }

    public func refreshIfNeeded() {
        let now = Date().timeIntervalSince1970
        self.lock.lock()
        let isStale = now - self.snapshot.fetchedAt > EcoBadges.refreshInterval
        let canRetry = now - self.lastAttempt > EcoBadges.retryInterval
        guard isStale, canRetry, !self.isRefreshing else {
            self.lock.unlock()
            return
        }
        self.isRefreshing = true
        self.lastAttempt = now
        self.lock.unlock()

        let task = self.session.dataTask(with: EcoBadges.badgesUrl, completionHandler: { [weak self] data, response, _ in
            guard let self else {
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let snapshot = status == 200 ? data.flatMap(EcoBadges.parse) : nil
            self.lock.lock()
            self.isRefreshing = false
            if let snapshot {
                self.snapshot = snapshot
            }
            self.lock.unlock()
            if let snapshot {
                self.persist(snapshot)
            }
        })
        task.resume()
    }

    public func claimEarlyBadge(telegramId: Int64, completion: @escaping (Bool) -> Void) {
        let finish: (Bool) -> Void = { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
        guard telegramId > 0, EcoPreferences.shared.showEcoBadges, !self.defaults.bool(forKey: EcoBadges.earlyClaimSettledKey) else {
            finish(false)
            return
        }
        self.lock.lock()
        let isKnownClosed = self.snapshot.fetchedAt > 0.0 && !self.snapshot.earlyOpen
        guard !self.isClaiming, !isKnownClosed else {
            self.lock.unlock()
            finish(false)
            return
        }
        self.isClaiming = true
        self.lock.unlock()

        var request = URLRequest(url: EcoBadges.earlyUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["telegramId": telegramId])

        let task = self.session.dataTask(with: request, completionHandler: { [weak self] data, response, _ in
            guard let self else {
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let claimStatus = status == 200 ? data.flatMap(EcoBadges.parseClaimStatus) : nil
            let granted = claimStatus == "granted"

            self.lock.lock()
            self.isClaiming = false
            if granted {
                self.snapshot.early.insert(telegramId)
            }
            let snapshot = self.snapshot
            self.lock.unlock()

            if claimStatus != nil {
                self.defaults.set(true, forKey: EcoBadges.earlyClaimSettledKey)
            }
            if granted {
                self.persist(snapshot)
            }
            finish(granted)
        })
        task.resume()
    }

    private func persist(_ snapshot: Snapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: self.cacheUrl, options: .atomic)
        }
    }

    private static func parse(_ data: Data) -> Snapshot? {
        guard let object = try? JSONSerialization.jsonObject(with: data), let root = object as? [String: Any] else {
            return nil
        }
        func ids(_ key: String) -> Set<Int64>? {
            guard let values = root[key] as? [Any] else {
                return nil
            }
            return Set(values.compactMap { ($0 as? NSNumber)?.int64Value })
        }
        guard let developers = ids("developers"), let early = ids("early"), let officialChannels = ids("officialChannels"), let earlyOpen = root["earlyOpen"] as? Bool else {
            return nil
        }
        return Snapshot(developers: developers, early: early, officialChannels: officialChannels, earlyOpen: earlyOpen, fetchedAt: Date().timeIntervalSince1970)
    }

    private static func parseClaimStatus(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data), let root = object as? [String: Any] else {
            return nil
        }
        return root["status"] as? String
    }
}
