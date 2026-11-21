import Foundation
import SGSimpleSettings

public final class EcoPreferences {
    public static let shared = EcoPreferences()
    public static let didChange = Notification.Name("ecogram.preferencesDidChange")

    private enum Key: String {
        case backgroundNotifications
        case hideProfileShortcuts
        case islandAvatarAnimation
        case selectionOrder
        case selectionEnabled
        case contextOrder
        case contextEnabled
        case badgeOrder
        case showEcoBadges
        case allowsProtectedScreenshots
        case swiftgramDefaultsApplied = "swiftgramDefaultsApplied.v2"

        var name: String {
            return "ecogram." + self.rawValue
        }
    }

    private let defaults: UserDefaults
    private let badgeOrderLock = NSLock()
    private var cachedBadgeOrder: [EcoBadgeSource]?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaults.register(defaults: [
            Key.backgroundNotifications.name: true,
            Key.hideProfileShortcuts.name: false,
            Key.islandAvatarAnimation.name: true,
            Key.showEcoBadges.name: true,
            Key.allowsProtectedScreenshots.name: false
        ])
        self.applySwiftgramDefaults()
    }

    public var backgroundNotifications: Bool {
        get { return self.defaults.bool(forKey: Key.backgroundNotifications.name) }
        set { self.store(newValue, .backgroundNotifications) }
    }

    public var hideProfileShortcuts: Bool {
        get { return self.defaults.bool(forKey: Key.hideProfileShortcuts.name) }
        set { self.store(newValue, .hideProfileShortcuts) }
    }

    public var islandAvatarAnimation: Bool {
        get { return self.defaults.bool(forKey: Key.islandAvatarAnimation.name) }
        set { self.store(newValue, .islandAvatarAnimation) }
    }

    public var allowsProtectedScreenshots: Bool {
        get { return self.defaults.bool(forKey: Key.allowsProtectedScreenshots.name) }
        set { self.store(newValue, .allowsProtectedScreenshots) }
    }

    public var showEcoBadges: Bool {
        get { return self.defaults.bool(forKey: Key.showEcoBadges.name) }
        set { self.store(newValue, .showEcoBadges) }
    }

    public var badgeOrder: [EcoBadgeSource] {
        self.badgeOrderLock.lock()
        defer {
            self.badgeOrderLock.unlock()
        }
        if let cached = self.cachedBadgeOrder {
            return cached
        }
        let order: [EcoBadgeSource] = self.ordered(key: .badgeOrder, all: EcoBadgeSource.allCases)
        self.cachedBadgeOrder = order
        return order
    }

    public func setBadgeOrder(_ order: [EcoBadgeSource]) {
        self.badgeOrderLock.lock()
        self.defaults.set(order.map { $0.rawValue }, forKey: Key.badgeOrder.name)
        self.cachedBadgeOrder = nil
        self.badgeOrderLock.unlock()
        NotificationCenter.default.post(name: EcoPreferences.didChange, object: self)
    }

    public var selectionOrder: [EcoSelectionAction] {
        return self.ordered(key: .selectionOrder, all: EcoSelectionAction.allCases)
    }

    public var enabledSelectionActions: [EcoSelectionAction] {
        return Array(self.selectionOrder.filter { self.isEnabled($0) }.prefix(EcoSelectionAction.maximumEnabled))
    }

    public func isEnabled(_ action: EcoSelectionAction) -> Bool {
        return self.enabledSet(key: .selectionEnabled, defaults: EcoSelectionAction.enabledByDefault).contains(action)
    }

    @discardableResult
    public func setEnabled(_ action: EcoSelectionAction, _ value: Bool) -> Bool {
        var enabled = self.enabledSet(key: .selectionEnabled, defaults: EcoSelectionAction.enabledByDefault)
        if value {
            if !enabled.contains(action) && enabled.count >= EcoSelectionAction.maximumEnabled {
                return false
            }
            enabled.insert(action)
        } else {
            enabled.remove(action)
        }
        self.store(enabled.map { $0.rawValue }.sorted(), .selectionEnabled)
        return true
    }

    public func setSelectionOrder(_ order: [EcoSelectionAction]) {
        self.store(order.map { $0.rawValue }, .selectionOrder)
    }

    public var contextOrder: [EcoContextAction] {
        return self.ordered(key: .contextOrder, all: EcoContextAction.allCases)
    }

    public var enabledContextActions: [EcoContextAction] {
        return self.contextOrder.filter { self.isEnabled($0) }
    }

    public func isEnabled(_ action: EcoContextAction) -> Bool {
        let settings = SGSimpleSettings.shared
        switch action {
        case .reply:
            return settings.contextShowReply
        case .pin:
            return settings.contextShowPin
        case .restrict:
            return settings.contextShowRestrict
        case .selectFromAuthor:
            return settings.contextShowSelectFromUser
        case .saveToFiles:
            return settings.contextShowSaveMedia
        case .report:
            return settings.contextShowReport
        case .viewReplies:
            return settings.contextShowMessageReplies
        case .saveToCloud:
            return settings.contextShowSaveToCloud
        case .hideForwardName:
            return settings.contextShowHideForwardName
        case .json:
            return settings.contextShowJson
        default:
            return self.enabledSet(key: .contextEnabled, defaults: EcoContextAction.enabledByDefault).contains(action)
        }
    }

    public func isManagedBySwiftgram(_ action: EcoContextAction) -> Bool {
        switch action {
        case .reply, .pin, .restrict, .selectFromAuthor, .saveToFiles, .report, .viewReplies, .saveToCloud, .hideForwardName, .json:
            return true
        default:
            return false
        }
    }

    public func setEnabled(_ action: EcoContextAction, _ value: Bool) {
        let settings = SGSimpleSettings.shared
        switch action {
        case .reply:
            settings.contextShowReply = value
        case .pin:
            settings.contextShowPin = value
        case .restrict:
            settings.contextShowRestrict = value
        case .selectFromAuthor:
            settings.contextShowSelectFromUser = value
        case .saveToFiles:
            settings.contextShowSaveMedia = value
        case .report:
            settings.contextShowReport = value
        case .viewReplies:
            settings.contextShowMessageReplies = value
        case .saveToCloud:
            settings.contextShowSaveToCloud = value
        case .hideForwardName:
            settings.contextShowHideForwardName = value
        case .json:
            settings.contextShowJson = value
        default:
            var enabled = self.enabledSet(key: .contextEnabled, defaults: EcoContextAction.enabledByDefault)
            if value {
                enabled.insert(action)
            } else {
                enabled.remove(action)
            }
            self.store(enabled.map { $0.rawValue }.sorted(), .contextEnabled)
            return
        }
        NotificationCenter.default.post(name: EcoPreferences.didChange, object: self)
    }

    public func setContextOrder(_ order: [EcoContextAction]) {
        self.store(order.map { $0.rawValue }, .contextOrder)
    }

    private func applySwiftgramDefaults() {
        guard !self.defaults.bool(forKey: Key.swiftgramDefaultsApplied.name) else {
            return
        }
        let settings = SGSimpleSettings.shared
        settings.contextShowReport = false
        settings.contextShowSaveMedia = false
        settings.contextShowMessageReplies = false
        settings.contextShowSaveToCloud = false
        settings.contextShowHideForwardName = false
        settings.contextShowJson = false
        settings.contextShowReply = true
        settings.contextShowPin = true
        settings.contextShowRestrict = true
        settings.contextShowSelectFromUser = true
        self.defaults.set(true, forKey: Key.swiftgramDefaultsApplied.name)
    }

    private func ordered<T: RawRepresentable & CaseIterable & Equatable>(key: Key, all: T.AllCases) -> [T] where T.RawValue == String {
        let stored = (self.defaults.stringArray(forKey: key.name) ?? []).compactMap(T.init(rawValue:))
        var result: [T] = []
        for item in stored where !result.contains(item) {
            result.append(item)
        }
        for item in all where !result.contains(item) {
            result.append(item)
        }
        return result
    }

    private func enabledSet<T: RawRepresentable & Hashable>(key: Key, defaults: Set<T>) -> Set<T> where T.RawValue == String {
        guard let stored = self.defaults.stringArray(forKey: key.name) else {
            return defaults
        }
        return Set(stored.compactMap(T.init(rawValue:)))
    }

    private func store(_ value: Any, _ key: Key) {
        self.defaults.set(value, forKey: key.name)
        NotificationCenter.default.post(name: EcoPreferences.didChange, object: self)
    }
}
