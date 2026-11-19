import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import PresentationDataUtils
import LocalizedPeerData
import AyuSettings
import EcoStrings

private enum AyuGhostExceptionSection: Int32 {
    case remove
    case options
}

private func ayuGhostExceptionEntries(strings: EcoStrings, presentationStrings: PresentationStrings, options: AyuGhostOptions, canRemove: Bool) -> [AyuListEntry] {
    var entries: [AyuListEntry] = []
    var order = 0
    func next() -> Int {
        order += 1
        return order
    }

    if canRemove {
        entries.append(.centered(section: AyuGhostExceptionSection.remove.rawValue, order: next(), action: .removeException, title: presentationStrings.Notification_Exceptions_RemoveFromExceptions))
    }

    let section = AyuGhostExceptionSection.options.rawValue
    entries.append(.toggle(section: section, order: next(), key: "hideRead", title: strings.get(.ghostHideRead), value: options.hideRead, enabled: true))
    entries.append(.toggle(section: section, order: next(), key: "keepUnread", title: strings.get(.ghostKeepUnread), value: options.keepUnread, enabled: options.hideRead))
    entries.append(.toggle(section: section, order: next(), key: "readOnInteract", title: strings.get(.ghostReadOnInteract), value: options.readOnInteract, enabled: options.hideRead))
    entries.append(.toggle(section: section, order: next(), key: "hideStories", title: strings.get(.ghostHideStoryViews), value: options.hideStories, enabled: true))
    entries.append(.toggle(section: section, order: next(), key: "hideTyping", title: strings.get(.ghostHideTyping), value: options.hideTyping, enabled: true))
    entries.append(.notice(section: section, order: next(), text: strings.get(.exceptionsFooter)))

    return entries
}

private func ayuUpdatedGhostOptions(_ options: AyuGhostOptions, key: String, value: Bool) -> AyuGhostOptions {
    var options = options
    switch key {
    case "hideRead":
        options.hideRead = value
    case "keepUnread":
        options.keepUnread = value
    case "readOnInteract":
        options.readOnInteract = value
    case "hideStories":
        options.hideStories = value
    case "hideTyping":
        options.hideTyping = value
    default:
        break
    }
    return options
}

func ayuGhostExceptionController(context: AccountContext, peer: EnginePeer, existing: AyuGhostOptions?, apply: @escaping (AyuGhostOptions?) -> Void) -> ViewController {
    let initial = existing ?? AyuSettings.shared.ghostOptions
    let optionsValue = Atomic<AyuGhostOptions>(value: initial)
    let optionsPromise = ValuePromise<AyuGhostOptions>(initial, ignoreRepeated: true)
    let canRemove = existing != nil
    var dismissImpl: (() -> Void)?

    let arguments = AyuListArguments(context: context, toggle: { key, value in
        optionsPromise.set(optionsValue.modify { ayuUpdatedGhostOptions($0, key: key, value: value) })
    }, perform: { action in
        if case .removeException = action {
            apply(nil)
            dismissImpl?()
        }
    })

    let signal = combineLatest(context.sharedContext.presentationData, optionsPromise.get())
    |> map { presentationData, options -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let leftNavigationButton = ItemListNavigationButton(content: .icon(.close), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let rightNavigationButton = ItemListNavigationButton(content: canRemove ? .icon(.done) : .text(presentationData.strings.Notification_Exceptions_Add), style: .bold, enabled: true, action: {
            apply(optionsValue.with { $0 })
            dismissImpl?()
        })
        let title = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ayuGhostExceptionEntries(strings: strings, presentationStrings: presentationData.strings, options: options, canRemove: canRemove), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.enableInteractiveDismiss = true
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    return controller
}
