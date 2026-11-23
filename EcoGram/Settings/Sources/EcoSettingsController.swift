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
import AyuSettings
import AyuSettingsUI
import EcoBadges
import EcoPreferences
import EcoStrings
import EcoListUI

private let ecoHasDynamicIsland = DeviceMetrics(screenSize: UIScreen.main.bounds.size, scale: UIScreen.main.scale, statusBarHeight: 0.0, onScreenNavigationHeight: nil).hasDynamicIsland

enum EcoSettingsAction: Hashable {
    case notificationSettings
    case selectionPanel
    case contextMenu
    case appearance
    case badges
    case spy
    case ayuCategory(AyuCategory)
    case protectedChats
}

private enum EcoSettingsSection: Int32 {
    case notifications
    case chat
    case appearance
    case spy
}

private enum EcoToggle: String {
    case localNotifications
    case hideProfileShortcuts
    case islandAvatarAnimation
}

typealias EcoSettingsEntry = EcoListEntry<EcoSettingsAction>

private struct EcoAppearanceOptions {
    let values: [Bool]

    init(preferences: EcoPreferences) {
        var values = [preferences.hideProfileShortcuts]
        if !ecoHasDynamicIsland {
            values.append(preferences.islandAvatarAnimation)
        }
        self.values = values
    }

    var enabled: Int {
        return self.values.filter { $0 }.count
    }
}

func ecoSettingsChanges() -> Signal<Void, NoError> {
    return Signal { subscriber in
        let center = NotificationCenter.default
        let observers = [EcoPreferences.didChange, AyuSettings.didChange].map { name in
            return center.addObserver(forName: name, object: nil, queue: .main, using: { _ in
                subscriber.putNext(Void())
            })
        }
        return ActionDisposable {
            for observer in observers {
                center.removeObserver(observer)
            }
        }
    }
}

private func ecoSettingsEntries(strings: EcoStrings, presentationStrings: PresentationStrings, theme: PresentationTheme) -> [EcoSettingsEntry] {
    let preferences = EcoPreferences.shared
    let iconColor = theme.list.itemAccentColor
    var entries: [EcoSettingsEntry] = []
    var order = 0
    func next() -> Int {
        order += 1
        return order
    }

    let notifications = EcoSettingsSection.notifications.rawValue
    entries.append(.header(section: notifications, order: next(), text: strings.get(.notificationsHeader)))
    entries.append(.toggle(section: notifications, order: next(), key: EcoToggle.localNotifications.rawValue, title: strings.get(.notificationsBackground), value: preferences.backgroundNotifications, enabled: true))
    entries.append(.disclosure(section: notifications, order: next(), action: .notificationSettings, title: strings.get(.notificationSettings), label: ""))
    entries.append(.notice(section: notifications, order: next(), text: strings.get(.notificationsFooter)))

    let chat = EcoSettingsSection.chat.rawValue
    let selectionEnabled = preferences.enabledSelectionActions.count
    let selectionTotal = EcoSelectionAction.allCases.count
    let contextEnabled = EcoContextAction.allCases.filter { preferences.isEnabled($0) }.count
    let contextTotal = EcoContextAction.allCases.count
    entries.append(.header(section: chat, order: next(), text: strings.get(.chatHeader)))
    entries.append(.category(section: chat, order: next(), action: .selectionPanel, icon: ecoOutlineIcon("Chat/Context Menu/Select", color: iconColor), title: strings.get(.selectionPanel), subtitle: ecoCountLabel(strings, enabled: selectionEnabled, total: selectionTotal), label: ecoStateLabel(presentationStrings, enabled: selectionEnabled, total: selectionTotal)))
    entries.append(.category(section: chat, order: next(), action: .contextMenu, icon: ecoOutlineIcon("Chat/Context Menu/More", color: iconColor), title: strings.get(.contextMenu), subtitle: ecoCountLabel(strings, enabled: contextEnabled, total: contextTotal), label: ecoStateLabel(presentationStrings, enabled: contextEnabled, total: contextTotal)))
    entries.append(.notice(section: chat, order: next(), text: strings.get(.chatFooter)))

    let appearance = EcoSettingsSection.appearance.rawValue
    let appearanceOptions = EcoAppearanceOptions(preferences: preferences)
    let badgesEnabled = EcoBadgeSource.allCases.filter(ecoBadgeSourceEnabled).count
    let badgesTotal = EcoBadgeSource.allCases.count
    let badgesIcon = ecoCategoryIcon(key: "ecogram.badge.developer", color: iconColor, image: { EcoBadgeImages.image(.developer, side: 24.0) })
    entries.append(.header(section: appearance, order: next(), text: strings.get(.appearanceHeader)))
    entries.append(.category(section: appearance, order: next(), action: .appearance, icon: ecoOutlineIcon("Chat/Context Menu/Palette", color: iconColor), title: strings.get(.appearanceTitle), subtitle: ecoCountLabel(strings, enabled: appearanceOptions.enabled, total: appearanceOptions.values.count), label: ecoStateLabel(presentationStrings, enabled: appearanceOptions.enabled, total: appearanceOptions.values.count)))
    entries.append(.category(section: appearance, order: next(), action: .badges, icon: badgesIcon, title: strings.get(.badgesTitle), subtitle: ecoCountLabel(strings, enabled: badgesEnabled, total: badgesTotal), label: ecoStateLabel(presentationStrings, enabled: badgesEnabled, total: badgesTotal)))

    let spy = EcoSettingsSection.spy.rawValue
    let spyCounts = ecoSpyCounts(strings: strings, presentationStrings: presentationStrings, theme: theme)
    entries.append(.header(section: spy, order: next(), text: strings.get(.spyEssentials)))
    entries.append(.category(section: spy, order: next(), action: .spy, icon: ecoOutlineIcon("Chat/Context Menu/Eye", color: iconColor), title: strings.get(.spyTitle), subtitle: ecoCountLabel(strings, enabled: spyCounts.enabled, total: spyCounts.total), label: ecoStateLabel(presentationStrings, enabled: spyCounts.enabled, total: spyCounts.total)))

    return entries
}

private func ecoAppearanceEntries(strings: EcoStrings) -> [EcoSettingsEntry] {
    let preferences = EcoPreferences.shared
    let section = EcoSettingsSection.appearance.rawValue
    var entries: [EcoSettingsEntry] = []
    var order = 0
    func next() -> Int {
        order += 1
        return order
    }
    entries.append(.toggle(section: section, order: next(), key: EcoToggle.hideProfileShortcuts.rawValue, title: strings.get(.hideProfileShortcuts), value: preferences.hideProfileShortcuts, enabled: true))
    if !ecoHasDynamicIsland {
        entries.append(.toggle(section: section, order: next(), key: EcoToggle.islandAvatarAnimation.rawValue, title: strings.get(.islandAvatarAnimation), value: preferences.islandAvatarAnimation, enabled: true))
        entries.append(.notice(section: section, order: next(), text: strings.get(.islandAvatarFooter)))
    }
    return entries
}

private func ecoApplyToggle(_ key: String, _ value: Bool) {
    let preferences = EcoPreferences.shared
    switch EcoToggle(rawValue: key) {
    case .localNotifications:
        preferences.backgroundNotifications = value
    case .hideProfileShortcuts:
        preferences.hideProfileShortcuts = value
    case .islandAvatarAnimation:
        preferences.islandAvatarAnimation = value
    case .none:
        break
    }
}

private func ecoAppearanceController(context: AccountContext) -> ViewController {
    let arguments = EcoListArguments<EcoSettingsAction>(context: context, toggle: ecoApplyToggle, perform: { _ in })
    let signal = combineLatest(Signal<Void, NoError>.single(Void()) |> then(ecoSettingsChanges()), context.sharedContext.presentationData)
    |> map { _, presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.appearanceTitle)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ecoAppearanceEntries(strings: strings), style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }
    return ItemListController(context: context, state: signal)
}

public func ecoSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = EcoListArguments<EcoSettingsAction>(context: context, toggle: ecoApplyToggle, perform: { action in
        switch action {
        case .notificationSettings:
            pushControllerImpl?(notificationsAndSoundsController(context: context, exceptionsList: nil))
        case .selectionPanel:
            pushControllerImpl?(ecoSelectionPanelController(context: context))
        case .contextMenu:
            pushControllerImpl?(ecoContextMenuController(context: context))
        case .appearance:
            pushControllerImpl?(ecoAppearanceController(context: context))
        case .badges:
            pushControllerImpl?(ecoBadgesController(context: context))
        case .spy:
            pushControllerImpl?(ecoSpyController(context: context))
        case let .ayuCategory(category):
            pushControllerImpl?(ayuCategoryController(category, context: context))
        case .protectedChats:
            pushControllerImpl?(ecoProtectedChatsController(context: context))
        }
    })

    let signal = combineLatest(Signal<Void, NoError>.single(Void()) |> then(ecoSettingsChanges()), context.sharedContext.presentationData)
    |> map { _, presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.settingsTitle)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ecoSettingsEntries(strings: strings, presentationStrings: presentationData.strings, theme: presentationData.theme), style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}
