import Foundation
import UIKit
import AyuBadges
import EcoPreferences
import EcoStrings

public enum EcoTitleBadge: Equatable {
    case ayu(AyuBadgeKind)
    case eco(EcoBadgeKind)

    public func image(side: CGFloat) -> UIImage? {
        switch self {
        case let .ayu(kind):
            return AyuBadgeImages.image(kind, side: side)?.withRenderingMode(.alwaysTemplate)
        case let .eco(kind):
            return EcoBadgeImages.image(kind, side: side)
        }
    }

    public var infoKey: EcoStrings.Key {
        switch self {
        case .ayu(.official):
            return .badgeOfficialInfo
        case .ayu(.supporter):
            return .badgeSupporterInfo
        case .eco(.developer):
            return .badgeDeveloperInfo
        case .eco(.early):
            return .badgeEarlyInfo
        case .eco(.official):
            return .badgeChannelInfo
        }
    }
}

public struct EcoTitleBadges: Equatable {
    public static let empty = EcoTitleBadges(leading: [], trailing: [])

    public let leading: [EcoTitleBadge]
    public let trailing: [EcoTitleBadge]

    public var isEmpty: Bool {
        return self.leading.isEmpty && self.trailing.isEmpty
    }

    public func totalWidth(side: CGFloat, spacing: CGFloat) -> CGFloat {
        let leadingWidth = EcoTitleBadges.width(count: self.leading.count, side: side, spacing: spacing)
        let trailingWidth = EcoTitleBadges.width(count: self.trailing.count, side: side, spacing: spacing)
        let gap = !self.leading.isEmpty && !self.trailing.isEmpty ? spacing : 0.0
        return leadingWidth + trailingWidth + gap
    }

    private static let aliasLock = NSLock()
    private static var aliases: [Int64: Int64] = [:]

    public static func registerAlias(_ alias: Int64, for id: Int64) {
        self.aliasLock.lock()
        self.aliases[alias] = id
        self.aliasLock.unlock()
    }

    public static func resolve(id: Int64, isChannel: Bool) -> EcoTitleBadges {
        self.aliasLock.lock()
        let id = self.aliases[id] ?? id
        self.aliasLock.unlock()

        var leading: [EcoTitleBadge] = []
        var trailing: [EcoTitleBadge] = []
        var isAfterTelegram = false
        for source in EcoPreferences.shared.badgeOrder {
            let badge: EcoTitleBadge?
            switch source {
            case .telegram:
                isAfterTelegram = true
                continue
            case .ayugram:
                badge = AyuBadges.shared.badge(id: id, isChannel: isChannel).map(EcoTitleBadge.ayu)
            case .ecogram:
                badge = EcoBadges.shared.badge(id: id, isChannel: isChannel).map(EcoTitleBadge.eco)
            }
            guard let badge else {
                continue
            }
            if isAfterTelegram {
                trailing.append(badge)
            } else {
                leading.append(badge)
            }
        }
        return EcoTitleBadges(leading: leading, trailing: trailing)
    }

    public static func width(count: Int, side: CGFloat, spacing: CGFloat) -> CGFloat {
        guard count > 0 else {
            return 0.0
        }
        return CGFloat(count) * side + CGFloat(count - 1) * spacing
    }
}
