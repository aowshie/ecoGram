import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import PresentationDataUtils
import SettingsUI
import SGItemListUI
import EcoPreferences
import EcoStrings

private let ecoHasDynamicIsland = DeviceMetrics(screenSize: UIScreen.main.bounds.size, scale: UIScreen.main.scale, statusBarHeight: 0.0, onScreenNavigationHeight: nil).hasDynamicIsland

private enum EcoSettingsSection: Int32, SGItemListSection {
    case notifications
    case chat
    case appearance
    case badges
}

private enum EcoToggle: Hashable {
    case localNotifications
    case avatarInTabBar
    case islandAvatarAnimation
    case hideProfileShortcuts
}

private enum EcoLink: Hashable {
    case notificationSettings
    case selectionPanel
    case contextMenu
    case badges
}

private typealias EcoEntry = SGItemListUIEntry<EcoSettingsSection, EcoToggle, Int, Int, EcoLink, Int>

private func ecoSettingsEntries(strings: EcoStrings) -> [EcoEntry] {
    let preferences = EcoPreferences.shared
    let id = SGItemListCounter()
    var entries: [EcoEntry] = []

    entries.append(.header(id: id.count, section: .notifications, text: strings.get(.notificationsHeader), badge: nil))
    entries.append(.toggle(id: id.count, section: .notifications, settingName: .localNotifications, value: preferences.backgroundNotifications, text: strings.get(.notificationsBackground), enabled: true))
    entries.append(.disclosure(id: id.count, section: .notifications, link: .notificationSettings, text: strings.get(.notificationSettings)))
    entries.append(.notice(id: id.count, section: .notifications, text: strings.get(.notificationsFooter)))

    entries.append(.header(id: id.count, section: .chat, text: strings.get(.chatHeader), badge: nil))
    entries.append(.disclosure(id: id.count, section: .chat, link: .selectionPanel, text: strings.get(.selectionPanel)))
    entries.append(.disclosure(id: id.count, section: .chat, link: .contextMenu, text: strings.get(.contextMenu)))
    entries.append(.notice(id: id.count, section: .chat, text: strings.get(.chatFooter)))

    entries.append(.header(id: id.count, section: .appearance, text: strings.get(.appearanceHeader), badge: nil))
    entries.append(.toggle(id: id.count, section: .appearance, settingName: .avatarInTabBar, value: preferences.avatarInTabBar, text: strings.get(.avatarInTabBar), enabled: true))
    entries.append(.toggle(id: id.count, section: .appearance, settingName: .hideProfileShortcuts, value: preferences.hideProfileShortcuts, text: strings.get(.hideProfileShortcuts), enabled: true))
    if !ecoHasDynamicIsland {
        entries.append(.toggle(id: id.count, section: .appearance, settingName: .islandAvatarAnimation, value: preferences.islandAvatarAnimation, text: strings.get(.islandAvatarAnimation), enabled: true))
        entries.append(.notice(id: id.count, section: .appearance, text: strings.get(.islandAvatarFooter)))
    }

    entries.append(.header(id: id.count, section: .badges, text: strings.get(.badgesHeader), badge: nil))
    entries.append(.disclosure(id: id.count, section: .badges, link: .badges, text: strings.get(.badgesTitle)))

    return entries
}

public func ecoSettingsController(context: AccountContext) -> ViewController {
    let refresh = ValuePromise<Bool>(true, ignoreRepeated: false)
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = SGItemListArguments<EcoToggle, Int, Int, EcoLink, Int>(context: context, setBoolValue: { toggle, value in
        switch toggle {
        case .localNotifications:
            EcoPreferences.shared.backgroundNotifications = value
        case .avatarInTabBar:
            EcoPreferences.shared.avatarInTabBar = value
        case .islandAvatarAnimation:
            EcoPreferences.shared.islandAvatarAnimation = value
        case .hideProfileShortcuts:
            EcoPreferences.shared.hideProfileShortcuts = value
        }
        refresh.set(true)
    }, openDisclosureLink: { link in
        switch link {
        case .notificationSettings:
            pushControllerImpl?(notificationsAndSoundsController(context: context, exceptionsList: nil))
        case .selectionPanel:
            pushControllerImpl?(ecoSelectionPanelController(context: context))
        case .contextMenu:
            pushControllerImpl?(ecoContextMenuController(context: context))
        case .badges:
            pushControllerImpl?(ecoBadgesController(context: context))
        }
    })

    let signal = combineLatest(refresh.get(), context.sharedContext.presentationData)
    |> map { _, presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.settingsTitle)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ecoSettingsEntries(strings: strings), style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}
