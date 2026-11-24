import Foundation

enum AyuShotTheme: String, CaseIterable {
    case app
    case day
    case night
}

struct AyuShotOptions: Hashable {
    private enum Key: String {
        case theme
        case showBackground
        case showTails
        case showDate
        case showReactions
        case showEdited
        case ownOnRight
        case anonymous
        case hideBadges

        var name: String {
            return "ecogram.shot." + self.rawValue
        }
    }

    var theme: AyuShotTheme
    var showBackground: Bool
    var showTails: Bool
    var showDate: Bool
    var showReactions: Bool
    var showEdited: Bool
    var ownOnRight: Bool
    var anonymous: Bool
    var hideBadges: Bool

    static var stored: AyuShotOptions {
        let defaults = UserDefaults.standard
        func value(_ key: Key, _ fallback: Bool) -> Bool {
            return defaults.object(forKey: key.name) as? Bool ?? fallback
        }
        return AyuShotOptions(
            theme: defaults.string(forKey: Key.theme.name).flatMap(AyuShotTheme.init(rawValue:)) ?? .app,
            showBackground: value(.showBackground, true),
            showTails: value(.showTails, true),
            showDate: value(.showDate, false),
            showReactions: value(.showReactions, true),
            showEdited: value(.showEdited, true),
            ownOnRight: value(.ownOnRight, false),
            anonymous: value(.anonymous, false),
            hideBadges: value(.hideBadges, false)
        )
    }

    func store() {
        let defaults = UserDefaults.standard
        defaults.set(self.theme.rawValue, forKey: Key.theme.name)
        defaults.set(self.showBackground, forKey: Key.showBackground.name)
        defaults.set(self.showTails, forKey: Key.showTails.name)
        defaults.set(self.showDate, forKey: Key.showDate.name)
        defaults.set(self.showReactions, forKey: Key.showReactions.name)
        defaults.set(self.showEdited, forKey: Key.showEdited.name)
        defaults.set(self.ownOnRight, forKey: Key.ownOnRight.name)
        defaults.set(self.anonymous, forKey: Key.anonymous.name)
        defaults.set(self.hideBadges, forKey: Key.hideBadges.name)
    }
}
