import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import PresentationDataUtils
import SGItemListUI
import AyuSettings
import EcoStrings

private enum EcoSettingsSection: Int32, SGItemListSection {
    case ghost
    case history
    case badges
    case notifications
}

private enum EcoToggle: Hashable {
    case ghostMode
    case hideRead
    case hideOnline
    case hideTyping
    case hideStoryViews
    case saveDeleted
    case saveEdited
    case saveBots
    case badges
    case backgroundNotifications
}

private enum EcoSelector: Hashable {
    case mediaLimit
    case cleanup
}

private enum EcoLink: Hashable {
    case savedHistory
}

private typealias EcoEntry = SGItemListUIEntry<EcoSettingsSection, EcoToggle, Int, EcoSelector, EcoLink, Int>

private func ecoSettingsEntries(strings: EcoStrings) -> [EcoEntry] {
    let settings = AyuSettings.shared
    let id = SGItemListCounter()
    var entries: [EcoEntry] = []

    entries.append(.header(id: id.count, section: .ghost, text: strings.get(.ghostHeader), badge: nil))
    entries.append(.toggle(id: id.count, section: .ghost, settingName: .ghostMode, value: settings.ghostMode, text: strings.get(.ghostMode), enabled: true))
    entries.append(.toggle(id: id.count, section: .ghost, settingName: .hideRead, value: settings.ghostHidesReadReceipts, text: strings.get(.ghostHideRead), enabled: settings.ghostMode))
    entries.append(.toggle(id: id.count, section: .ghost, settingName: .hideOnline, value: settings.ghostHidesOnline, text: strings.get(.ghostHideOnline), enabled: settings.ghostMode))
    entries.append(.toggle(id: id.count, section: .ghost, settingName: .hideTyping, value: settings.ghostHidesTyping, text: strings.get(.ghostHideTyping), enabled: settings.ghostMode))
    entries.append(.toggle(id: id.count, section: .ghost, settingName: .hideStoryViews, value: settings.ghostHidesStoryViews, text: strings.get(.ghostHideStoryViews), enabled: settings.ghostMode))
    entries.append(.notice(id: id.count, section: .ghost, text: strings.get(.ghostFooter)))

    entries.append(.header(id: id.count, section: .history, text: strings.get(.historyHeader), badge: nil))
    entries.append(.toggle(id: id.count, section: .history, settingName: .saveDeleted, value: settings.saveDeletedMessages, text: strings.get(.historySaveDeleted), enabled: true))
    entries.append(.toggle(id: id.count, section: .history, settingName: .saveEdited, value: settings.saveEditedMessages, text: strings.get(.historySaveEdited), enabled: true))
    entries.append(.toggle(id: id.count, section: .history, settingName: .saveBots, value: settings.saveInBots, text: strings.get(.historySaveBots), enabled: settings.saveDeletedMessages || settings.saveEditedMessages))
    entries.append(.oneFromManySelector(id: id.count, section: .history, settingName: .mediaLimit, text: strings.get(.historyMediaLimit), value: strings.mediaLimit(settings.historyMediaLimitMegabytes), enabled: settings.saveDeletedMessages))
    entries.append(.oneFromManySelector(id: id.count, section: .history, settingName: .cleanup, text: strings.get(.historyCleanup), value: strings.cleanupPeriod(settings.historyCleanupDays), enabled: true))
    entries.append(.disclosure(id: id.count, section: .history, link: .savedHistory, text: strings.get(.historyOpen)))
    entries.append(.notice(id: id.count, section: .history, text: strings.get(.historyFooter)))

    entries.append(.header(id: id.count, section: .badges, text: strings.get(.badgesHeader), badge: nil))
    entries.append(.toggle(id: id.count, section: .badges, settingName: .badges, value: settings.showAyuBadges, text: strings.get(.badgesShow), enabled: true))
    entries.append(.notice(id: id.count, section: .badges, text: strings.get(.badgesFooter)))

    entries.append(.header(id: id.count, section: .notifications, text: strings.get(.notificationsHeader), badge: nil))
    entries.append(.toggle(id: id.count, section: .notifications, settingName: .backgroundNotifications, value: settings.backgroundNotifications, text: strings.get(.notificationsBackground), enabled: true))
    entries.append(.notice(id: id.count, section: .notifications, text: strings.get(.notificationsFooter)))

    return entries
}

private func applyToggle(_ toggle: EcoToggle, value: Bool) {
    let settings = AyuSettings.shared
    switch toggle {
    case .ghostMode:
        settings.ghostMode = value
    case .hideRead:
        settings.ghostHidesReadReceipts = value
    case .hideOnline:
        settings.ghostHidesOnline = value
    case .hideTyping:
        settings.ghostHidesTyping = value
    case .hideStoryViews:
        settings.ghostHidesStoryViews = value
    case .saveDeleted:
        settings.saveDeletedMessages = value
    case .saveEdited:
        settings.saveEditedMessages = value
    case .saveBots:
        settings.saveInBots = value
    case .badges:
        settings.showAyuBadges = value
    case .backgroundNotifications:
        settings.backgroundNotifications = value
    }
}

public func ecoSettingsController(context: AccountContext) -> ViewController {
    let refresh = ValuePromise<Bool>(true, ignoreRepeated: false)
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentSelectorImpl: ((EcoSelector, [SGOneFromManyOption]) -> Void)?

    let arguments = SGItemListArguments<EcoToggle, Int, EcoSelector, EcoLink, Int>(context: context, setBoolValue: { toggle, value in
        applyToggle(toggle, value: value)
        refresh.set(true)
    }, setOneFromManyValue: { selector in
        let strings = EcoStrings(languageCode: context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode)
        let settings = AyuSettings.shared
        let options: [SGOneFromManyOption]
        switch selector {
        case .mediaLimit:
            options = AyuSettings.mediaLimitOptions.map { value in
                SGOneFromManyOption(title: strings.mediaLimit(value), isSelected: settings.historyMediaLimitMegabytes == value, action: {
                    settings.historyMediaLimitMegabytes = value
                    refresh.set(true)
                })
            }
        case .cleanup:
            options = AyuSettings.cleanupOptions.map { value in
                SGOneFromManyOption(title: strings.cleanupPeriod(value), isSelected: settings.historyCleanupDays == value, action: {
                    settings.historyCleanupDays = value
                    ecoHistoryStore(context: context).cleanup()
                    refresh.set(true)
                })
            }
        }
        presentSelectorImpl?(selector, options)
    }, openDisclosureLink: { link in
        switch link {
        case .savedHistory:
            pushControllerImpl?(ecoSavedHistoryController(context: context))
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
    presentSelectorImpl = { [weak controller] selector, options in
        guard let controller else {
            return
        }
        sgPresentOneFromManySelector(controller: controller, setting: selector, presentationData: context.sharedContext.currentPresentationData.with { $0 }, options: options)
    }
    return controller
}
