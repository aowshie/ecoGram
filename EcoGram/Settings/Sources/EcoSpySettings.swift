import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import AyuSettingsUI
import EcoPreferences
import EcoStrings
import EcoListUI

private enum EcoSpySection: Int32 {
    case ayugram
    case ecogram
    case content
    case forward
}

private enum EcoProtectedToggle: String {
    case screenshots
    case copy
    case saving
    case forward
}

private let ecoSpyCategories: [AyuCategory] = [.ghost, .history]

private func ecoProtectedChatsCount() -> (enabled: Int, total: Int) {
    let options = EcoPreferences.shared.protectedChatOptions
    return (options.filter { $0 }.count, options.count)
}

func ecoSpyCounts(strings: EcoStrings, presentationStrings: PresentationStrings, theme: PresentationTheme) -> (enabled: Int, total: Int) {
    let summaries = ecoSpyCategories.map { ayuCategorySummary($0, strings: strings, presentationStrings: presentationStrings, theme: theme) }
    let protected = ecoProtectedChatsCount()
    return (summaries.reduce(protected.enabled) { $0 + $1.enabled }, summaries.reduce(protected.total) { $0 + $1.total })
}

private func ecoSpyEntries(strings: EcoStrings, presentationStrings: PresentationStrings, theme: PresentationTheme) -> [EcoSettingsEntry] {
    var entries: [EcoSettingsEntry] = []
    var order = 0
    func next() -> Int {
        order += 1
        return order
    }
    let ayugram = EcoSpySection.ayugram.rawValue
    entries.append(.header(section: ayugram, order: next(), text: strings.get(.ayuTitle).uppercased()))
    for category in ecoSpyCategories {
        let summary = ayuCategorySummary(category, strings: strings, presentationStrings: presentationStrings, theme: theme)
        entries.append(.category(section: ayugram, order: next(), action: .ayuCategory(category), icon: summary.icon, title: summary.title, subtitle: summary.subtitle, label: summary.label))
    }
    let ecogram = EcoSpySection.ecogram.rawValue
    let protected = ecoProtectedChatsCount()
    entries.append(.header(section: ecogram, order: next(), text: strings.get(.settingsTitle).uppercased()))
    entries.append(.category(section: ecogram, order: next(), action: .protectedChats, icon: ecoOutlineIcon("Chat/Context Menu/Lock", color: theme.list.itemAccentColor), title: strings.get(.protectedChats), subtitle: ecoCountLabel(strings, enabled: protected.enabled, total: protected.total), label: ecoStateLabel(presentationStrings, enabled: protected.enabled, total: protected.total)))
    return entries
}

private func ecoProtectedChatsEntries(strings: EcoStrings) -> [EcoSettingsEntry] {
    let preferences = EcoPreferences.shared
    var entries: [EcoSettingsEntry] = []
    var order = 0
    func next() -> Int {
        order += 1
        return order
    }
    let content = EcoSpySection.content.rawValue
    entries.append(.toggle(section: content, order: next(), key: EcoProtectedToggle.screenshots.rawValue, title: strings.get(.spyScreenshots), value: preferences.allowsProtectedScreenshots, enabled: true))
    entries.append(.toggle(section: content, order: next(), key: EcoProtectedToggle.copy.rawValue, title: strings.get(.protectedCopy), value: preferences.allowsProtectedCopy, enabled: true))
    entries.append(.toggle(section: content, order: next(), key: EcoProtectedToggle.saving.rawValue, title: strings.get(.protectedSaving), value: preferences.allowsProtectedSaving, enabled: true))
    entries.append(.notice(section: content, order: next(), text: strings.get(.spyScreenshotsFooter)))
    let forward = EcoSpySection.forward.rawValue
    entries.append(.toggle(section: forward, order: next(), key: EcoProtectedToggle.forward.rawValue, title: strings.get(.protectedForward), value: preferences.forwardsProtectedAsShot, enabled: true))
    entries.append(.notice(section: forward, order: next(), text: strings.get(.protectedForwardFooter)))
    return entries
}

private func ecoApplyProtectedToggle(_ key: String, _ value: Bool) {
    let preferences = EcoPreferences.shared
    switch EcoProtectedToggle(rawValue: key) {
    case .screenshots:
        preferences.allowsProtectedScreenshots = value
    case .copy:
        preferences.allowsProtectedCopy = value
    case .saving:
        preferences.allowsProtectedSaving = value
    case .forward:
        preferences.forwardsProtectedAsShot = value
    case .none:
        break
    }
}

func ecoSpyController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    let arguments = EcoListArguments<EcoSettingsAction>(context: context, toggle: { _, _ in }, perform: { action in
        switch action {
        case let .ayuCategory(category):
            pushControllerImpl?(ayuCategoryController(category, context: context))
        case .protectedChats:
            pushControllerImpl?(ecoProtectedChatsController(context: context))
        default:
            break
        }
    })
    let signal = combineLatest(Signal<Void, NoError>.single(Void()) |> then(ecoSettingsChanges()), context.sharedContext.presentationData)
    |> map { _, presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.spyTitle)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ecoSpyEntries(strings: strings, presentationStrings: presentationData.strings, theme: presentationData.theme), style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}

func ecoProtectedChatsController(context: AccountContext) -> ViewController {
    let arguments = EcoListArguments<EcoSettingsAction>(context: context, toggle: ecoApplyProtectedToggle, perform: { _ in })
    let signal = combineLatest(Signal<Void, NoError>.single(Void()) |> then(ecoSettingsChanges()), context.sharedContext.presentationData)
    |> map { _, presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.protectedChats)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ecoProtectedChatsEntries(strings: strings), style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }
    return ItemListController(context: context, state: signal)
}
