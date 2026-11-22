import Foundation
import UIKit
import Display
import TelegramPresentationData
import AccountContext
import AyuSettings
import EcoStrings
import EcoListUI

public enum AyuCategory: Hashable {
    case ghost
    case history
}

public struct AyuCategorySummary {
    public let icon: UIImage?
    public let title: String
    public let subtitle: String
    public let label: String
    public let enabled: Int
    public let total: Int
}

public func ayuCategorySummary(_ category: AyuCategory, strings: EcoStrings, presentationStrings: PresentationStrings, theme: PresentationTheme) -> AyuCategorySummary {
    let settings = AyuSettings.shared
    let iconColor = theme.list.itemAccentColor
    switch category {
    case .ghost:
        let enabled = settings.ghostEnabledCount
        let total = AyuSettings.ghostOptionCount
        var subtitle = ecoCountLabel(strings, enabled: enabled, total: total)
        let exceptionCount = settings.ghostExceptions.count
        if exceptionCount > 0 {
            subtitle += ", " + presentationStrings.Notifications_CategoryExceptions(Int32(exceptionCount))
        }
        return AyuCategorySummary(icon: ecoOutlineIcon("Premium/Stories/Stealth", color: iconColor), title: strings.get(.ghostMode), subtitle: subtitle, label: ecoStateLabel(presentationStrings, enabled: enabled, total: total), enabled: enabled, total: total)
    case .history:
        let options = [settings.saveDeletedMessages, settings.saveEditedMessages, settings.keepsSelfDestructingMedia]
        let enabled = options.filter { $0 }.count
        let total = options.count
        return AyuCategorySummary(icon: ecoOutlineIcon("Chat/Context Menu/Message", color: iconColor), title: strings.get(.historyTitle), subtitle: ecoCountLabel(strings, enabled: enabled, total: total), label: ecoStateLabel(presentationStrings, enabled: enabled, total: total), enabled: enabled, total: total)
    }
}

public func ayuCategoryController(_ category: AyuCategory, context: AccountContext) -> ViewController {
    switch category {
    case .ghost:
        return ayuGhostController(context: context)
    case .history:
        return ayuHistoryController(context: context)
    }
}
