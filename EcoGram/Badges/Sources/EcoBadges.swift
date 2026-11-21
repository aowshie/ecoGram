import Foundation
import EcoPreferences

public enum EcoBadgeKind: Equatable {
    case developer
    case early
    case official
}

public final class EcoBadges {
    public static let shared = EcoBadges()
    public static let didUpdate = Notification.Name("ecogram.badgesDidUpdate")

    private struct Snapshot: Codable {
        var developers: Set<Int64>
        var early: Set<Int64>
        var officialChannels: Set<Int64>
        var earlyOpen: Bool
        var fetchedAt: Double

        func hasSameBadges(as other: Snapshot) -> Bool {
            return self.developers == other.developers && self.early == other.early && self.officialChannels == other.officialChannels
        }

        static let empty = Snapshot(developers: [], early: [], officialChannels: [], earlyOpen: true, fetchedAt: 0.0)
    }

    private static let badgesUrl = URL(string: "https://api.ecogram.cc/v1/badges")!
    private static let earlyUrl = URL(string: "https://api.ecogram.cc/v1/early")!
    private static let refreshInterval: TimeInterval = 5 * 60
    private static let retryInterval: TimeInterval = 2 * 60
    private static let earlyClaimSettledKey = "ecogram.earlyBadge.settled"
    private static let earlyAlertPendingKey = "ecogram.earlyBadge.alertPending"
    private static let ownEarlyIdKey = "ecogram.earlyBadge.ownId"

    private let lock = NSLock()
    private var snapshot: Snapshot
    private var isRefreshing = false
    private var isClaiming = false
    private var isEarlyAlertReserved = false
    private var lastAttempt: TimeInterval = 0.0
    private var ownEarlyId: Int64?
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
        self.ownEarlyId = (defaults.object(forKey: EcoBadges.ownEarlyIdKey) as? NSNumber)?.int64Value
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
        let ownEarlyId = self.ownEarlyId
        self.lock.unlock()
        if isChannel {
            return snapshot.officialChannels.contains(id) ? .official : nil
        }
        if snapshot.developers.contains(id) {
            return .developer
        }
        if snapshot.early.contains(id) || id == ownEarlyId {
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
            let previous = self.snapshot
            if let snapshot {
                self.snapshot = snapshot
            }
            self.lock.unlock()
            guard let snapshot else {
                return
            }
            self.persist(snapshot)
            if !snapshot.hasSameBadges(as: previous) {
                EcoBadges.notifyUpdate()
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
            let isEarlyUser = claimStatus == "granted" || claimStatus == "already"

            self.lock.lock()
            self.isClaiming = false
            if isEarlyUser {
                self.ownEarlyId = telegramId
            }
            self.lock.unlock()

            if isEarlyUser {
                self.defaults.set(NSNumber(value: telegramId), forKey: EcoBadges.ownEarlyIdKey)
                self.defaults.set(true, forKey: EcoBadges.earlyAlertPendingKey)
                EcoBadges.notifyUpdate()
            }
            if claimStatus != nil {
                self.defaults.set(true, forKey: EcoBadges.earlyClaimSettledKey)
            }
            finish(isEarlyUser)
        })
        task.resume()
    }

    public var hasPendingEarlyAlert: Bool {
        return self.defaults.bool(forKey: EcoBadges.earlyAlertPendingKey)
    }

    public func reserveEarlyAlert() -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        guard self.hasPendingEarlyAlert, !self.isEarlyAlertReserved else {
            return false
        }
        self.isEarlyAlertReserved = true
        return true
    }

    public func markEarlyAlertShown() {
        self.defaults.set(false, forKey: EcoBadges.earlyAlertPendingKey)
    }

    private static func notifyUpdate() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: EcoBadges.didUpdate, object: EcoBadges.shared)
        }
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
