import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import PresentationDataUtils
import AyuSettings
import EcoStrings

private enum AyuGhostSection: Int32 {
    case master
    case options
    case exceptions
}

private func ayuGhostEntries(strings: EcoStrings, presentationStrings: PresentationStrings, exceptions: [(EnginePeer, Bool)]) -> [AyuListEntry] {
    let settings = AyuSettings.shared
    var entries: [AyuListEntry] = []
    var order = 0
    func next() -> Int {
        order += 1
        return order
    }

    entries.append(.toggle(section: AyuGhostSection.master.rawValue, order: next(), key: "ghostMode", title: strings.get(.ghostMode), value: settings.ghostMode, enabled: true))

    let readSuppressed = settings.ghostHidesReadReceipts
    entries.append(.toggle(section: AyuGhostSection.options.rawValue, order: next(), key: "hideRead", title: strings.get(.ghostHideRead), value: readSuppressed, enabled: true))
    entries.append(.toggle(section: AyuGhostSection.options.rawValue, order: next(), key: "keepUnread", title: strings.get(.ghostKeepUnread), value: settings.ghostKeepsUnread, enabled: readSuppressed))
    entries.append(.toggle(section: AyuGhostSection.options.rawValue, order: next(), key: "readOnInteract", title: strings.get(.ghostReadOnInteract), value: settings.ghostReadOnInteract, enabled: readSuppressed))
    entries.append(.toggle(section: AyuGhostSection.options.rawValue, order: next(), key: "hideStories", title: strings.get(.ghostHideStoryViews), value: settings.ghostHidesStoryViews, enabled: true))
    entries.append(.toggle(section: AyuGhostSection.options.rawValue, order: next(), key: "hideOnline", title: strings.get(.ghostHideOnline), value: settings.ghostHidesOnline, enabled: true))
    entries.append(.toggle(section: AyuGhostSection.options.rawValue, order: next(), key: "hideTyping", title: strings.get(.ghostHideTyping), value: settings.ghostHidesTyping, enabled: true))
    entries.append(.notice(section: AyuGhostSection.options.rawValue, order: next(), text: strings.get(.ghostFooter)))

    entries.append(.header(section: AyuGhostSection.exceptions.rawValue, order: next(), text: strings.get(.exceptionsHeader)))
    entries.append(.peerAction(section: AyuGhostSection.exceptions.rawValue, order: next(), action: .addException, title: presentationStrings.Notification_Exceptions_AddException))
    for (peer, value) in exceptions {
        entries.append(.peer(section: AyuGhostSection.exceptions.rawValue, order: next(), peer: peer, value: value ? presentationStrings.Notification_Exceptions_AlwaysOn : presentationStrings.Notification_Exceptions_AlwaysOff))
    }
    if !exceptions.isEmpty {
        entries.append(.destructive(section: AyuGhostSection.exceptions.rawValue, order: next(), action: .deleteExceptions, title: presentationStrings.Notification_Exceptions_DeleteAll))
    }
    entries.append(.notice(section: AyuGhostSection.exceptions.rawValue, order: next(), text: strings.get(.exceptionsFooter)))

    return entries
}

private func ayuApplyGhostToggle(_ key: String, value: Bool) {
    let settings = AyuSettings.shared
    switch key {
    case "ghostMode":
        settings.ghostMode = value
    case "hideRead":
        settings.ghostHidesReadReceipts = value
    case "keepUnread":
        settings.ghostKeepsUnread = value
    case "readOnInteract":
        settings.ghostReadOnInteract = value
    case "hideStories":
        settings.ghostHidesStoryViews = value
    case "hideOnline":
        settings.ghostHidesOnline = value
    case "hideTyping":
        settings.ghostHidesTyping = value
    default:
        break
    }
}

private func ayuExceptionPeers(context: AccountContext, refresh: Signal<Bool, NoError>) -> Signal<[(EnginePeer, Bool)], NoError> {
    return refresh
    |> mapToSignal { _ -> Signal<[(EnginePeer, Bool)], NoError> in
        let exceptions = AyuSettings.shared.ghostExceptions
        let ids = exceptions.keys.sorted().map { EnginePeer.Id($0) }
        if ids.isEmpty {
            return .single([])
        }
        return context.engine.data.get(EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))))
        |> map { peers -> [(EnginePeer, Bool)] in
            var result: [(EnginePeer, Bool)] = []
            for id in ids {
                if let maybePeer = peers[id], let peer = maybePeer, let value = exceptions[id.toInt64()] {
                    result.append((peer, value))
                }
            }
            return result
        }
    }
}

func ayuGhostController(context: AccountContext, onChange: @escaping () -> Void) -> ViewController {
    let refresh = ValuePromise<Bool>(true, ignoreRepeated: false)
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let changed: () -> Void = {
        refresh.set(true)
        onChange()
    }

    let presentChoice: (EnginePeer.Id, Bool, @escaping () -> Void) -> Void = { peerId, allowsRemove, completion in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings
        var actions: [TextAlertAction] = [
            TextAlertAction(type: .genericAction, title: strings.Notification_Exceptions_AlwaysOn, action: {
                AyuSettings.shared.setGhostException(peerId: peerId.toInt64(), value: true)
                changed()
                completion()
            }),
            TextAlertAction(type: .genericAction, title: strings.Notification_Exceptions_AlwaysOff, action: {
                AyuSettings.shared.setGhostException(peerId: peerId.toInt64(), value: false)
                changed()
                completion()
            })
        ]
        if allowsRemove {
            actions.append(TextAlertAction(type: .destructiveAction, title: strings.Common_Delete, action: {
                AyuSettings.shared.setGhostException(peerId: peerId.toInt64(), value: nil)
                changed()
                completion()
            }))
        }
        actions.append(TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: {}))
        let ecoStrings = EcoStrings(languageCode: strings.baseLanguageCode)
        presentControllerImpl?(textAlertController(context: context, title: nil, text: ecoStrings.get(.ghostMode), actions: actions, actionLayout: .vertical))
    }

    let arguments = AyuListArguments(context: context, toggle: { key, value in
        ayuApplyGhostToggle(key, value: value)
        changed()
    }, perform: { action in
        switch action {
        case .addException:
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.excludeRecent, .doNotSearchMessages, .removeSearchHeader, .excludeSavedMessages, .excludeSecretChats], hasContactSelector: false, title: presentationData.strings.Notifications_AddExceptionTitle))
            controller.peerSelected = { [weak controller] peer, _ in
                presentChoice(peer.id, false, {
                    controller?.dismiss()
                })
            }
            pushControllerImpl?(controller)
        case .deleteExceptions:
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Notification_Exceptions_DeleteAllConfirmation, actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                    AyuSettings.shared.ghostExceptions = [:]
                    changed()
                })
            ]))
        default:
            break
        }
    }, openPeer: { peer in
        presentChoice(peer.id, true, {})
    }, removePeer: { peerId in
        AyuSettings.shared.setGhostException(peerId: peerId.toInt64(), value: nil)
        changed()
    })

    let signal = combineLatest(refresh.get(), context.sharedContext.presentationData, ayuExceptionPeers(context: context, refresh: refresh.get()))
    |> map { _, presentationData, exceptions -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.ghostMode)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ayuGhostEntries(strings: strings, presentationStrings: presentationData.strings, exceptions: exceptions), style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
