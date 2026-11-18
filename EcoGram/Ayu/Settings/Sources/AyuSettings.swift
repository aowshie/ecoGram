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
        case saveDeletedMessages
        case saveEditedMessages
        case saveInBots
        case historyMediaLimitMegabytes
        case historyCleanupDays
        case showAyuBadges
        case backgroundNotifications

        var name: String {
            return "ecogram.ayu." + self.rawValue
        }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaults.register(defaults: [
            Key.ghostMode.name: false,
            Key.ghostHidesReadReceipts.name: true,
            Key.ghostHidesOnline.name: true,
            Key.ghostHidesTyping.name: true,
            Key.ghostHidesStoryViews.name: true,
            Key.saveDeletedMessages.name: true,
            Key.saveEditedMessages.name: true,
            Key.saveInBots.name: false,
            Key.historyMediaLimitMegabytes.name: 20,
            Key.historyCleanupDays.name: 0,
            Key.showAyuBadges.name: true,
            Key.backgroundNotifications.name: true
        ])
    }

    public var ghostMode: Bool {
        get { return self.bool(.ghostMode) }
        set { self.set(newValue, .ghostMode) }
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

    public var backgroundNotifications: Bool {
        get { return self.bool(.backgroundNotifications) }
        set { self.set(newValue, .backgroundNotifications) }
    }

    public var suppressReadReceipts: Bool {
        return self.ghostMode && self.ghostHidesReadReceipts
    }

    public var suppressOnline: Bool {
        return self.ghostMode && self.ghostHidesOnline
    }

    public var suppressTyping: Bool {
        return self.ghostMode && self.ghostHidesTyping
    }

    public var suppressStoryViews: Bool {
        return self.ghostMode && self.ghostHidesStoryViews
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
