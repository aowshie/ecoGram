import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import SGItemListUI
import AyuSettings
import EcoStrings
import EcoListUI
import EcoStorage

private enum AyuMainSection: Int32 {
    case ghost
    case spy
    case badges
}

private func ayuMainEntries(strings: EcoStrings, presentationStrings: PresentationStrings, theme: PresentationTheme) -> [AyuListEntry] {
    let settings = AyuSettings.shared
    var entries: [AyuListEntry] = []
    var order = 0
    func next() -> Int {
        order += 1
        return order
    }

    let ghost = ayuCategorySummary(.ghost, strings: strings, presentationStrings: presentationStrings, theme: theme)
    entries.append(.header(section: AyuMainSection.ghost.rawValue, order: next(), text: strings.get(.ghostEssentials)))
    entries.append(.category(section: AyuMainSection.ghost.rawValue, order: next(), action: .openGhost, icon: ghost.icon, title: ghost.title, subtitle: ghost.subtitle, label: ghost.label))

    let history = ayuCategorySummary(.history, strings: strings, presentationStrings: presentationStrings, theme: theme)
    entries.append(.header(section: AyuMainSection.spy.rawValue, order: next(), text: strings.get(.spyEssentials)))
    entries.append(.category(section: AyuMainSection.spy.rawValue, order: next(), action: .openHistory, icon: history.icon, title: history.title, subtitle: history.subtitle, label: history.label))

    entries.append(.header(section: AyuMainSection.badges.rawValue, order: next(), text: strings.get(.badgesHeader)))
    entries.append(.toggle(section: AyuMainSection.badges.rawValue, order: next(), key: "badges", title: strings.get(.badgesShow), value: settings.showAyuBadges, enabled: true))
    entries.append(.linkNotice(section: AyuMainSection.badges.rawValue, order: next(), text: strings.get(.ayuBadgesFooter), action: .openBadges))

    return entries
}

private func ayuSettingsChanges() -> Signal<Void, NoError> {
    return Signal { subscriber in
        let observer = NotificationCenter.default.addObserver(forName: AyuSettings.didChange, object: nil, queue: .main, using: { _ in
            subscriber.putNext(Void())
        })
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

public func ayuSettingsController(context: AccountContext, badgesController: @escaping (AccountContext) -> ViewController) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = AyuListArguments(context: context, toggle: { key, value in
        if key == "badges" {
            AyuSettings.shared.showAyuBadges = value
        }
    }, perform: { action in
        switch action {
        case .openGhost:
            pushControllerImpl?(ayuCategoryController(.ghost, context: context))
        case .openHistory:
            pushControllerImpl?(ayuCategoryController(.history, context: context))
        case .openBadges:
            pushControllerImpl?(badgesController(context))
        default:
            break
        }
    })

    let signal = combineLatest(Signal<Void, NoError>.single(Void()) |> then(ayuSettingsChanges()), context.sharedContext.presentationData)
    |> map { _, presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.ayuTitle)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ayuMainEntries(strings: strings, presentationStrings: presentationData.strings, theme: presentationData.theme), style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
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
    case storage
}

private enum AyuHistoryToggle: Hashable {
    case saveDeleted
    case saveEdited
    case saveSelfDestructing
    case saveBots
}

private enum AyuHistoryLink: Hashable {
    case manageStorage
}

private typealias AyuHistoryEntry = SGItemListUIEntry<AyuHistorySection, AyuHistoryToggle, Int, Int, AyuHistoryLink, Int>

private func ayuHistoryEntries(strings: EcoStrings) -> [AyuHistoryEntry] {
    let settings = AyuSettings.shared
    let id = SGItemListCounter()
    var entries: [AyuHistoryEntry] = []

    entries.append(.toggle(id: id.count, section: .history, settingName: .saveDeleted, value: settings.saveDeletedMessages, text: strings.get(.historySaveDeleted), enabled: true))
    entries.append(.toggle(id: id.count, section: .history, settingName: .saveSelfDestructing, value: settings.saveSelfDestructing, text: strings.get(.historySaveSelfDestructing), enabled: settings.saveDeletedMessages))
    entries.append(.toggle(id: id.count, section: .history, settingName: .saveEdited, value: settings.saveEditedMessages, text: strings.get(.historySaveEdited), enabled: true))
    entries.append(.toggle(id: id.count, section: .history, settingName: .saveBots, value: settings.saveInBots, text: strings.get(.historySaveBots), enabled: settings.saveDeletedMessages || settings.saveEditedMessages))
    entries.append(.notice(id: id.count, section: .history, text: strings.get(.historyFooter)))
    entries.append(.disclosure(id: id.count, section: .storage, link: .manageStorage, text: strings.get(.manageStorage)))

    return entries
}

func ayuHistoryController(context: AccountContext) -> ViewController {
    let refresh = ValuePromise<Bool>(true, ignoreRepeated: false)
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = SGItemListArguments<AyuHistoryToggle, Int, Int, AyuHistoryLink, Int>(context: context, setBoolValue: { toggle, value in
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
    }, openDisclosureLink: { link in
        switch link {
        case .manageStorage:
            pushControllerImpl?(EcoUsageScreen(context: context))
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
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}
