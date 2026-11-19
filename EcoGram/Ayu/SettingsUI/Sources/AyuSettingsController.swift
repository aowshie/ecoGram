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

private enum AyuMainSection: Int32 {
    case ghost
    case spy
    case badges
}

private func ayuCountLabel(_ strings: EcoStrings, enabled: Int, total: Int) -> String {
    return String(format: strings.get(.ghostEnabledCount), enabled, total)
}

private func ayuStateLabel(_ presentationStrings: PresentationStrings, enabled: Int, total: Int) -> String {
    if enabled == total {
        return presentationStrings.Notifications_On
    }
    if enabled == 0 {
        return presentationStrings.Notifications_Off
    }
    return ""
}

private let ayuGhostIcon = renderSettingsIcon(name: "Item List/Icons/LastSeen", backgroundColors: [UIColor(rgb: 0x5E5CE6)])
private let ayuHistoryIcon = renderSettingsIcon(name: "Item List/Icons/Clock", backgroundColors: [UIColor(rgb: 0xFF9500)])

private func ayuMainEntries(strings: EcoStrings, presentationStrings: PresentationStrings) -> [AyuListEntry] {
    let settings = AyuSettings.shared
    var entries: [AyuListEntry] = []
    var order = 0
    func next() -> Int {
        order += 1
        return order
    }

    let ghostCount = settings.ghostEnabledCount
    let ghostTotal = AyuSettings.ghostOptionCount
    entries.append(.header(section: AyuMainSection.ghost.rawValue, order: next(), text: strings.get(.ghostEssentials)))
    var ghostSubtitle = ayuCountLabel(strings, enabled: ghostCount, total: ghostTotal)
    let exceptionCount = settings.ghostExceptions.count
    if exceptionCount > 0 {
        ghostSubtitle += ", " + presentationStrings.Notifications_CategoryExceptions(Int32(exceptionCount))
    }
    entries.append(.category(section: AyuMainSection.ghost.rawValue, order: next(), action: .openGhost, icon: ayuGhostIcon, title: strings.get(.ghostMode), subtitle: ghostSubtitle, label: ayuStateLabel(presentationStrings, enabled: ghostCount, total: ghostTotal)))

    let historyOptions = [settings.saveDeletedMessages, settings.saveEditedMessages, settings.saveSelfDestructing]
    let historyCount = historyOptions.filter { $0 }.count
    entries.append(.header(section: AyuMainSection.spy.rawValue, order: next(), text: strings.get(.spyEssentials)))
    entries.append(.category(section: AyuMainSection.spy.rawValue, order: next(), action: .openHistory, icon: ayuHistoryIcon, title: strings.get(.historyTitle), subtitle: ayuCountLabel(strings, enabled: historyCount, total: historyOptions.count), label: ayuStateLabel(presentationStrings, enabled: historyCount, total: historyOptions.count)))

    entries.append(.header(section: AyuMainSection.badges.rawValue, order: next(), text: strings.get(.badgesHeader)))
    entries.append(.toggle(section: AyuMainSection.badges.rawValue, order: next(), key: "badges", title: strings.get(.badgesShow), value: settings.showAyuBadges, enabled: true))
    entries.append(.notice(section: AyuMainSection.badges.rawValue, order: next(), text: strings.get(.badgesFooter)))

    return entries
}

public func ayuSettingsController(context: AccountContext) -> ViewController {
    let refresh = ValuePromise<Bool>(true, ignoreRepeated: false)
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = AyuListArguments(context: context, toggle: { key, value in
        if key == "badges" {
            AyuSettings.shared.showAyuBadges = value
        }
        refresh.set(true)
    }, perform: { action in
        switch action {
        case .openGhost:
            pushControllerImpl?(ayuGhostController(context: context, onChange: { refresh.set(true) }))
        case .openHistory:
            pushControllerImpl?(ayuHistoryController(context: context, onChange: { refresh.set(true) }))
        default:
            break
        }
    })

    let signal = combineLatest(refresh.get(), context.sharedContext.presentationData)
    |> map { _, presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.ayuTitle)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ayuMainEntries(strings: strings, presentationStrings: presentationData.strings), style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}

private enum AyuHistorySection: Int32, SGItemListSection {
    case history
}

private enum AyuHistoryToggle: Hashable {
    case saveDeleted
    case saveEdited
    case saveSelfDestructing
    case saveBots
}

private enum AyuSelector: Hashable {
    case mediaLimit
    case cleanup
}

private enum AyuHistoryAction: Hashable {
    case clearDeleted
}

private typealias AyuHistoryEntry = SGItemListUIEntry<AyuHistorySection, AyuHistoryToggle, Int, AyuSelector, Int, AyuHistoryAction>

private func ayuHistoryEntries(strings: EcoStrings) -> [AyuHistoryEntry] {
    let settings = AyuSettings.shared
    let id = SGItemListCounter()
    var entries: [AyuHistoryEntry] = []

    entries.append(.toggle(id: id.count, section: .history, settingName: .saveDeleted, value: settings.saveDeletedMessages, text: strings.get(.historySaveDeleted), enabled: true))
    entries.append(.toggle(id: id.count, section: .history, settingName: .saveSelfDestructing, value: settings.saveSelfDestructing, text: strings.get(.historySaveSelfDestructing), enabled: settings.saveDeletedMessages))
    entries.append(.toggle(id: id.count, section: .history, settingName: .saveEdited, value: settings.saveEditedMessages, text: strings.get(.historySaveEdited), enabled: true))
    entries.append(.toggle(id: id.count, section: .history, settingName: .saveBots, value: settings.saveInBots, text: strings.get(.historySaveBots), enabled: settings.saveDeletedMessages || settings.saveEditedMessages))
    entries.append(.oneFromManySelector(id: id.count, section: .history, settingName: .mediaLimit, text: strings.get(.historyMediaLimit), value: strings.mediaLimit(settings.historyMediaLimitMegabytes), enabled: settings.saveDeletedMessages))
    entries.append(.oneFromManySelector(id: id.count, section: .history, settingName: .cleanup, text: strings.get(.historyCleanup), value: strings.cleanupPeriod(settings.historyCleanupDays), enabled: true))
    entries.append(.action(id: id.count, section: .history, actionType: .clearDeleted, text: strings.get(.historyClearDeleted), kind: .destructive))
    entries.append(.notice(id: id.count, section: .history, text: strings.get(.historyFooter)))

    return entries
}

private func ayuHistoryController(context: AccountContext, onChange: @escaping () -> Void) -> ViewController {
    let refresh = ValuePromise<Bool>(true, ignoreRepeated: false)
    var presentControllerImpl: ((ViewController) -> Void)?
    var presentSelectorImpl: ((AyuSelector, [SGOneFromManyOption]) -> Void)?

    let arguments = SGItemListArguments<AyuHistoryToggle, Int, AyuSelector, Int, AyuHistoryAction>(context: context, setBoolValue: { toggle, value in
        let settings = AyuSettings.shared
        switch toggle {
        case .saveDeleted:
            settings.saveDeletedMessages = value
        case .saveEdited:
            settings.saveEditedMessages = value
        case .saveSelfDestructing:
            settings.saveSelfDestructing = value
        case .saveBots:
            settings.saveInBots = value
        }
        refresh.set(true)
        onChange()
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
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.historyTitle)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ayuHistoryEntries(strings: strings), style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
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
