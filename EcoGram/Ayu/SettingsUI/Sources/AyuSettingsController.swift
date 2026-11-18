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

private enum AyuSettingsSection: Int32, SGItemListSection {
    case ghost
    case history
    case badges
}

private enum AyuToggle: Hashable {
    case ghostMode
    case hideRead
    case hideOnline
    case hideTyping
    case hideStoryViews
    case keepUnread
    case saveDeleted
    case saveEdited
    case saveSelfDestructing
    case saveBots
    case badges
}

private enum AyuSelector: Hashable {
    case mediaLimit
    case cleanup
}

private enum AyuAction: Hashable {
    case clearDeleted
}

private typealias AyuEntry = SGItemListUIEntry<AyuSettingsSection, AyuToggle, Int, AyuSelector, Int, AyuAction>

private func ayuSettingsEntries(strings: EcoStrings) -> [AyuEntry] {
    let settings = AyuSettings.shared
    let id = SGItemListCounter()
    var entries: [AyuEntry] = []

    entries.append(.header(id: id.count, section: .ghost, text: strings.get(.ghostHeader), badge: nil))
    entries.append(.toggle(id: id.count, section: .ghost, settingName: .ghostMode, value: settings.ghostMode, text: strings.get(.ghostMode), enabled: true))
    entries.append(.toggle(id: id.count, section: .ghost, settingName: .hideRead, value: settings.ghostHidesReadReceipts, text: strings.get(.ghostHideRead), enabled: settings.ghostMode))
    entries.append(.toggle(id: id.count, section: .ghost, settingName: .hideOnline, value: settings.ghostHidesOnline, text: strings.get(.ghostHideOnline), enabled: settings.ghostMode))
    entries.append(.toggle(id: id.count, section: .ghost, settingName: .hideTyping, value: settings.ghostHidesTyping, text: strings.get(.ghostHideTyping), enabled: settings.ghostMode))
    entries.append(.toggle(id: id.count, section: .ghost, settingName: .hideStoryViews, value: settings.ghostHidesStoryViews, text: strings.get(.ghostHideStoryViews), enabled: settings.ghostMode))
    entries.append(.toggle(id: id.count, section: .ghost, settingName: .keepUnread, value: settings.ghostKeepsUnread, text: strings.get(.ghostKeepUnread), enabled: settings.ghostMode && settings.ghostHidesReadReceipts))
    entries.append(.notice(id: id.count, section: .ghost, text: strings.get(.ghostFooter)))

    entries.append(.header(id: id.count, section: .history, text: strings.get(.historyHeader), badge: nil))
    entries.append(.toggle(id: id.count, section: .history, settingName: .saveDeleted, value: settings.saveDeletedMessages, text: strings.get(.historySaveDeleted), enabled: true))
    entries.append(.toggle(id: id.count, section: .history, settingName: .saveSelfDestructing, value: settings.saveSelfDestructing, text: strings.get(.historySaveSelfDestructing), enabled: settings.saveDeletedMessages))
    entries.append(.toggle(id: id.count, section: .history, settingName: .saveEdited, value: settings.saveEditedMessages, text: strings.get(.historySaveEdited), enabled: true))
    entries.append(.toggle(id: id.count, section: .history, settingName: .saveBots, value: settings.saveInBots, text: strings.get(.historySaveBots), enabled: settings.saveDeletedMessages || settings.saveEditedMessages))
    entries.append(.oneFromManySelector(id: id.count, section: .history, settingName: .mediaLimit, text: strings.get(.historyMediaLimit), value: strings.mediaLimit(settings.historyMediaLimitMegabytes), enabled: settings.saveDeletedMessages))
    entries.append(.oneFromManySelector(id: id.count, section: .history, settingName: .cleanup, text: strings.get(.historyCleanup), value: strings.cleanupPeriod(settings.historyCleanupDays), enabled: true))
    entries.append(.action(id: id.count, section: .history, actionType: .clearDeleted, text: strings.get(.historyClearDeleted), kind: .destructive))
    entries.append(.notice(id: id.count, section: .history, text: strings.get(.historyFooter)))

    entries.append(.header(id: id.count, section: .badges, text: strings.get(.badgesHeader), badge: nil))
    entries.append(.toggle(id: id.count, section: .badges, settingName: .badges, value: settings.showAyuBadges, text: strings.get(.badgesShow), enabled: true))
    entries.append(.notice(id: id.count, section: .badges, text: strings.get(.badgesFooter)))

    return entries
}

private func applyToggle(_ toggle: AyuToggle, value: Bool) {
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
    case .keepUnread:
        settings.ghostKeepsUnread = value
    case .saveDeleted:
        settings.saveDeletedMessages = value
    case .saveEdited:
        settings.saveEditedMessages = value
    case .saveSelfDestructing:
        settings.saveSelfDestructing = value
    case .saveBots:
        settings.saveInBots = value
    case .badges:
        settings.showAyuBadges = value
    }
}

public func ayuSettingsController(context: AccountContext) -> ViewController {
    let refresh = ValuePromise<Bool>(true, ignoreRepeated: false)
    var presentControllerImpl: ((ViewController) -> Void)?
    var presentSelectorImpl: ((AyuSelector, [SGOneFromManyOption]) -> Void)?

    let arguments = SGItemListArguments<AyuToggle, Int, AyuSelector, Int, AyuAction>(context: context, setBoolValue: { toggle, value in
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
                    ayuExpireHistory(context: context)
                    refresh.set(true)
                })
            }
        }
        presentSelectorImpl?(selector, options)
    }, action: { action in
        switch action {
        case .clearDeleted:
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
            presentControllerImpl?(textAlertController(context: context, title: nil, text: strings.get(.historyClearDeletedConfirm), actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                    ayuClearDeleted(context: context)
                })
            ]))
        }
    })

    let signal = combineLatest(refresh.get(), context.sharedContext.presentationData)
    |> map { _, presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.ayuTitle)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ayuSettingsEntries(strings: strings), style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    presentSelectorImpl = { [weak controller] selector, options in
        guard let controller else {
            return
        }
        sgPresentOneFromManySelector(controller: controller, setting: selector, presentationData: context.sharedContext.currentPresentationData.with { $0 }, options: options)
    }
    return controller
}
