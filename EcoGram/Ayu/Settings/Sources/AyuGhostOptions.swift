import Foundation

public struct AyuGhostOptions: Equatable {
    public var hideRead: Bool
    public var keepUnread: Bool
    public var readOnInteract: Bool
    public var hideStories: Bool
    public var hideTyping: Bool

    public init(hideRead: Bool, keepUnread: Bool, readOnInteract: Bool, hideStories: Bool, hideTyping: Bool) {
        self.hideRead = hideRead
        self.keepUnread = keepUnread
        self.readOnInteract = readOnInteract
        self.hideStories = hideStories
        self.hideTyping = hideTyping
    }

    public var keepsUnread: Bool {
        return self.hideRead && self.keepUnread
    }

    public var readsOnInteract: Bool {
        return self.hideRead && self.readOnInteract
    }

    public var enabledCount: Int {
        return [self.hideRead, self.keepsUnread, self.readsOnInteract, self.hideStories, self.hideTyping].filter { $0 }.count
    }

    public static let optionCount = 5

    static let disabled = AyuGhostOptions(hideRead: false, keepUnread: false, readOnInteract: false, hideStories: false, hideTyping: false)

    private enum Key: String {
        case hideRead
        case keepUnread
        case readOnInteract
        case hideStories
        case hideTyping
    }

    var storage: [String: Bool] {
        return [
            Key.hideRead.rawValue: self.hideRead,
            Key.keepUnread.rawValue: self.keepUnread,
            Key.readOnInteract.rawValue: self.readOnInteract,
            Key.hideStories.rawValue: self.hideStories,
            Key.hideTyping.rawValue: self.hideTyping
        ]
    }

    init?(storage: Any, fallback: AyuGhostOptions) {
        if let enabled = storage as? Bool {
            self.init(hideRead: enabled, keepUnread: fallback.keepUnread, readOnInteract: fallback.readOnInteract, hideStories: enabled, hideTyping: enabled)
        } else if let values = storage as? [String: Bool] {
            self.init(
                hideRead: values[Key.hideRead.rawValue] ?? fallback.hideRead,
                keepUnread: values[Key.keepUnread.rawValue] ?? fallback.keepUnread,
                readOnInteract: values[Key.readOnInteract.rawValue] ?? fallback.readOnInteract,
                hideStories: values[Key.hideStories.rawValue] ?? fallback.hideStories,
                hideTyping: values[Key.hideTyping.rawValue] ?? fallback.hideTyping
            )
        } else {
            return nil
        }
    }
}
