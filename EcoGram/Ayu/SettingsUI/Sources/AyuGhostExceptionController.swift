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
    case hideRead
    case keepUnread
    case readOnInteract
    case hideStories
    case hideTyping
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

    func appendOption(_ section: AyuGhostExceptionSection, key: String, title: String, value: Bool) {
        entries.append(.header(section: section.rawValue, order: next(), text: title.uppercased()))
        entries.append(.choice(section: section.rawValue, order: next(), key: key, value: true, title: presentationStrings.Notification_Exceptions_AlwaysOn, checked: value))
        entries.append(.choice(section: section.rawValue, order: next(), key: key, value: false, title: presentationStrings.Notification_Exceptions_AlwaysOff, checked: !value))
    }

    appendOption(.hideRead, key: "hideRead", title: strings.get(.ghostHideRead), value: options.hideRead)
    if options.hideRead {
        appendOption(.keepUnread, key: "keepUnread", title: strings.get(.ghostKeepUnread), value: options.keepUnread)
        appendOption(.readOnInteract, key: "readOnInteract", title: strings.get(.ghostReadOnInteract), value: options.readOnInteract)
    }
    appendOption(.hideStories, key: "hideStories", title: strings.get(.ghostHideStoryViews), value: options.hideStories)
    appendOption(.hideTyping, key: "hideTyping", title: strings.get(.ghostHideTyping), value: options.hideTyping)
    entries.append(.notice(section: AyuGhostExceptionSection.hideTyping.rawValue, order: next(), text: strings.get(.exceptionsFooter)))

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

    let arguments = AyuListArguments(context: context, toggle: { _, _ in
    }, perform: { action in
        if case .removeException = action {
            apply(nil)
            dismissImpl?()
        }
    }, select: { key, value in
        optionsPromise.set(optionsValue.modify { ayuUpdatedGhostOptions($0, key: key, value: value) })
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
