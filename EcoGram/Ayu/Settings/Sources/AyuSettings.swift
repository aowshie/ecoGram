import Foundation

public final class AyuSettings {
    public static let shared = AyuSettings()
    public static let didChange = Notification.Name("ecogram.ayu.settingsDidChange")

    public static let mediaLimitOptions: [Int] = [0, 5, 20, 50, 200]
    public static let cleanupOptions: [Int] = [0, 7, 30, 90, 365]

    private enum Key: String {
        case ghostMode
        case ghostHidesReadReceipts
        case ghostHidesOnline
        case ghostHidesTyping
        case ghostHidesStoryViews
        case ghostKeepsUnread
        case ghostReadOnInteract
        case ghostExceptions
        case ghostMigrated = "ghostMigrated.v2"
        case saveDeletedMessages
        case saveEditedMessages
        case saveInBots
        case saveSelfDestructing
        case historyMediaLimitMegabytes
        case historyCleanupDays
        case showAyuBadges

        var name: String {
            return "ecogram.ayu." + self.rawValue
        }
    }

    private let defaults: UserDefaults
    private let exceptionsLock = NSLock()
    private var exceptionsCache: [Int64: AyuGhostOptions]?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.migrateGhostMode()
        self.migrateGhostExceptions()
        self.defaults.register(defaults: [
            Key.ghostMode.name: false,
            Key.ghostHidesReadReceipts.name: false,
            Key.ghostHidesOnline.name: false,
            Key.ghostHidesTyping.name: false,
            Key.ghostHidesStoryViews.name: false,
            Key.ghostKeepsUnread.name: false,
            Key.ghostReadOnInteract.name: true,
            Key.saveDeletedMessages.name: true,
            Key.saveEditedMessages.name: true,
            Key.saveInBots.name: false,
            Key.saveSelfDestructing.name: true,
            Key.historyMediaLimitMegabytes.name: 20,
            Key.historyCleanupDays.name: 0,
            Key.showAyuBadges.name: true
        ])
    }

    private func migrateGhostMode() {
        guard !self.defaults.bool(forKey: Key.ghostMigrated.name) else {
            return
        }
        let wasEnabled = self.defaults.bool(forKey: Key.ghostMode.name)
        for key in [Key.ghostHidesReadReceipts, .ghostHidesOnline, .ghostHidesTyping, .ghostHidesStoryViews] {
            let stored = self.defaults.object(forKey: key.name) as? Bool ?? true
            self.defaults.set(wasEnabled && stored, forKey: key.name)
        }
        self.defaults.removeObject(forKey: Key.ghostMode.name)
        self.defaults.set(true, forKey: Key.ghostMigrated.name)
    }

    private func migrateGhostExceptions() {
        guard let stored = self.defaults.dictionary(forKey: Key.ghostExceptions.name), stored.values.contains(where: { $0 is Bool }) else {
            return
        }
        let fallback = self.ghostOptions
        var migrated: [String: [String: Bool]] = [:]
        for (key, value) in stored {
            if let options = AyuGhostOptions(storage: value, fallback: fallback) {
                migrated[key] = options.storage
            }
        }
        self.defaults.set(migrated, forKey: Key.ghostExceptions.name)
    }

    public var ghostEnabledCount: Int {
        return [self.ghostHidesReadReceipts, self.ghostHidesStoryViews, self.ghostHidesOnline, self.ghostHidesTyping].filter { $0 }.count
    }

    public static let ghostOptionCount = 4

    public var ghostMode: Bool {
        get { return self.ghostEnabledCount == AyuSettings.ghostOptionCount }
        set {
            for key in [Key.ghostHidesReadReceipts, .ghostHidesOnline, .ghostHidesTyping, .ghostHidesStoryViews] {
                self.defaults.set(newValue, forKey: key.name)
            }
            NotificationCenter.default.post(name: AyuSettings.didChange, object: self)
        }
    }

    public var ghostReadOnInteract: Bool {
        get { return self.bool(.ghostReadOnInteract) }
        set { self.set(newValue, .ghostReadOnInteract) }
    }

    public var ghostOptions: AyuGhostOptions {
        return AyuGhostOptions(hideRead: self.ghostHidesReadReceipts, keepUnread: self.ghostKeepsUnread, readOnInteract: self.ghostReadOnInteract, hideStories: self.ghostHidesStoryViews, hideTyping: self.ghostHidesTyping)
    }

    public var ghostExceptions: [Int64: AyuGhostOptions] {
        get {
            self.exceptionsLock.lock()
            defer {
                self.exceptionsLock.unlock()
            }
            if let cached = self.exceptionsCache {
                return cached
            }
            let stored = self.defaults.dictionary(forKey: Key.ghostExceptions.name) ?? [:]
            var result: [Int64: AyuGhostOptions] = [:]
            for (key, value) in stored {
                if let peerId = Int64(key), let options = AyuGhostOptions(storage: value, fallback: AyuGhostOptions.disabled) {
                    result[peerId] = options
                }
            }
            self.exceptionsCache = result
            return result
        }
        set {
            var stored: [String: [String: Bool]] = [:]
            for (key, value) in newValue {
                stored[String(key)] = value.storage
            }
            self.exceptionsLock.lock()
            self.exceptionsCache = newValue
            self.exceptionsLock.unlock()
            self.set(stored, .ghostExceptions)
        }
    }

    public func ghostException(peerId: Int64) -> AyuGhostOptions? {
        return self.ghostExceptions[peerId]
    }

    public func setGhostException(peerId: Int64, options: AyuGhostOptions?) {
        var exceptions = self.ghostExceptions
        exceptions[peerId] = options
        self.ghostExceptions = exceptions
    }

    private func ghostEffective(_ peerId: Int64) -> AyuGhostOptions {
        return self.ghostException(peerId: peerId) ?? self.ghostOptions
    }

    public var ghostHidesReadReceipts: Bool {
        get { return self.bool(.ghostHidesReadReceipts) }
        set { self.set(newValue, .ghostHidesReadReceipts) }
    }

    public var ghostHidesOnline: Bool {
        get { return self.bool(.ghostHidesOnline) }
        set { self.set(newValue, .ghostHidesOnline) }
    }

    public var ghostHidesTyping: Bool {
        get { return self.bool(.ghostHidesTyping) }
        set { self.set(newValue, .ghostHidesTyping) }
    }

    public var ghostHidesStoryViews: Bool {
        get { return self.bool(.ghostHidesStoryViews) }
        set { self.set(newValue, .ghostHidesStoryViews) }
    }

    public var ghostKeepsUnread: Bool {
        get { return self.bool(.ghostKeepsUnread) }
        set { self.set(newValue, .ghostKeepsUnread) }
    }

    public var saveDeletedMessages: Bool {
        get { return self.bool(.saveDeletedMessages) }
        set { self.set(newValue, .saveDeletedMessages) }
    }

    public var saveEditedMessages: Bool {
        get { return self.bool(.saveEditedMessages) }
        set { self.set(newValue, .saveEditedMessages) }
    }

    public var saveInBots: Bool {
        get { return self.bool(.saveInBots) }
        set { self.set(newValue, .saveInBots) }
    }

    public var saveSelfDestructing: Bool {
        get { return self.bool(.saveSelfDestructing) }
        set { self.set(newValue, .saveSelfDestructing) }
    }

    public var historyMediaLimitMegabytes: Int {
        get { return self.defaults.integer(forKey: Key.historyMediaLimitMegabytes.name) }
        set { self.set(newValue, .historyMediaLimitMegabytes) }
    }

    public var historyCleanupDays: Int {
        get { return self.defaults.integer(forKey: Key.historyCleanupDays.name) }
        set { self.set(newValue, .historyCleanupDays) }
    }

    public var showAyuBadges: Bool {
        get { return self.bool(.showAyuBadges) }
        set { self.set(newValue, .showAyuBadges) }
    }

    public var suppressReadReceipts: Bool {
        return self.ghostHidesReadReceipts
    }

    public var suppressOnline: Bool {
        return self.ghostHidesOnline
    }

    public func suppressReadReceipts(peerId: Int64) -> Bool {
        return self.ghostEffective(peerId).hideRead
    }

    public func keepsMessagesUnread(peerId: Int64) -> Bool {
        return self.ghostEffective(peerId).keepsUnread
    }

    public func readsOnInteract(peerId: Int64) -> Bool {
        return self.ghostEffective(peerId).readsOnInteract
    }

    public func suppressTyping(peerId: Int64) -> Bool {
        return self.ghostEffective(peerId).hideTyping
    }

    public func suppressStoryViews(peerId: Int64) -> Bool {
        return self.ghostEffective(peerId).hideStories
    }

    public var historyMediaLimitBytes: Int64 {
        return Int64(self.historyMediaLimitMegabytes) * 1024 * 1024
    }

    private func bool(_ key: Key) -> Bool {
        return self.defaults.bool(forKey: key.name)
    }

    private func set(_ value: Any, _ key: Key) {
        self.defaults.set(value, forKey: key.name)
        NotificationCenter.default.post(name: AyuSettings.didChange, object: self)
    }
}
