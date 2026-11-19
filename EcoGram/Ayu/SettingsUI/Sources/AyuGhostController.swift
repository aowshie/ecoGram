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

private struct AyuGhostState: Equatable {
    var editing = false
    var revealedPeerId: EnginePeer.Id?
}

func ayuGhostSummary(_ options: AyuGhostOptions, strings: EcoStrings, presentationStrings: PresentationStrings) -> String {
    let enabled = options.enabledCount
    if enabled == AyuGhostOptions.optionCount {
        return presentationStrings.Notification_Exceptions_AlwaysOn
    }
    if enabled == 0 {
        return presentationStrings.Notification_Exceptions_AlwaysOff
    }
    return String(format: strings.get(.ghostEnabledCount), enabled, AyuGhostOptions.optionCount)
}

private func ayuGhostEntries(strings: EcoStrings, presentationStrings: PresentationStrings, state: AyuGhostState, exceptions: [(EnginePeer, AyuGhostOptions)]) -> [AyuListEntry] {
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

    entries.append(.header(section: AyuGhostSection.exceptions.rawValue, order: next(), text: presentationStrings.Notifications_MessageNotificationsExceptions))
    entries.append(.addPeer(section: AyuGhostSection.exceptions.rawValue, order: next(), title: presentationStrings.Notification_Exceptions_AddException))
    for (peer, options) in exceptions {
        entries.append(.peer(section: AyuGhostSection.exceptions.rawValue, order: next(), peer: peer, value: ayuGhostSummary(options, strings: strings, presentationStrings: presentationStrings), editing: state.editing, revealed: state.revealedPeerId == peer.id))
    }
    if !exceptions.isEmpty {
        entries.append(.deleteAll(section: AyuGhostSection.exceptions.rawValue, order: next(), title: presentationStrings.Notifications_DeleteAllExceptions))
    }

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

private func ayuExceptionPeers(context: AccountContext, refresh: Signal<Bool, NoError>) -> Signal<[(EnginePeer, AyuGhostOptions)], NoError> {
    return refresh
    |> mapToSignal { _ -> Signal<[(EnginePeer, AyuGhostOptions)], NoError> in
        let exceptions = AyuSettings.shared.ghostExceptions
        let ids = exceptions.keys.map { EnginePeer.Id($0) }
        if ids.isEmpty {
            return .single([])
        }
        return context.engine.data.get(EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))))
        |> map { peers -> [(EnginePeer, AyuGhostOptions)] in
            var result: [(EnginePeer, AyuGhostOptions)] = []
            for id in ids {
                if let maybePeer = peers[id], let peer = maybePeer, let options = exceptions[id.toInt64()] {
                    result.append((peer, options))
                }
            }
            return result.sorted(by: { $0.0.compactDisplayTitle.localizedCompare($1.0.compactDisplayTitle) == .orderedAscending })
        }
    }
}

func ayuGhostController(context: AccountContext, onChange: @escaping () -> Void) -> ViewController {
    let refresh = ValuePromise<Bool>(true, ignoreRepeated: false)
    let stateValue = Atomic<AyuGhostState>(value: AyuGhostState())
    let statePromise = ValuePromise<AyuGhostState>(AyuGhostState(), ignoreRepeated: true)
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let updateState: ((inout AyuGhostState) -> Void) -> Void = { f in
        statePromise.set(stateValue.modify { current in
            var current = current
            f(&current)
            return current
        })
    }

    let changed: () -> Void = {
        refresh.set(true)
        onChange()
    }

    let removeException: (EnginePeer.Id) -> Void = { peerId in
        AyuSettings.shared.setGhostException(peerId: peerId.toInt64(), options: nil)
        let isEmpty = AyuSettings.shared.ghostExceptions.isEmpty
        updateState {
            $0.revealedPeerId = nil
            if isEmpty {
                $0.editing = false
            }
        }
        changed()
    }

    let presentPeerSettings: (EnginePeer, @escaping () -> Void) -> Void = { peer, completion in
        completion()
        let existing = AyuSettings.shared.ghostException(peerId: peer.id.toInt64())
        pushControllerImpl?(ayuGhostExceptionController(context: context, peer: peer, existing: existing, apply: { options in
            AyuSettings.shared.setGhostException(peerId: peer.id.toInt64(), options: options)
            changed()
        }))
    }

    let arguments = AyuListArguments(context: context, toggle: { key, value in
        ayuApplyGhostToggle(key, value: value)
        changed()
    }, perform: { action in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        switch action {
        case .addException:
            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.excludeRecent, .doNotSearchMessages, .removeSearchHeader, .excludeSavedMessages, .excludeSecretChats], hasContactSelector: false, title: presentationData.strings.Notifications_AddExceptionTitle))
            controller.peerSelected = { [weak controller] peer, _ in
                presentPeerSettings(peer, {
                    controller?.dismiss()
                })
            }
            pushControllerImpl?(controller)
        case .deleteExceptions:
            let actionSheet = ActionSheetController(presentationData: presentationData)
            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: presentationData.strings.Notification_Exceptions_DeleteAllConfirmation),
                ActionSheetButtonItem(title: presentationData.strings.Notification_Exceptions_DeleteAll, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    AyuSettings.shared.ghostExceptions = [:]
                    updateState {
                        $0.editing = false
                        $0.revealedPeerId = nil
                    }
                    changed()
                })
            ]), ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])])
            presentControllerImpl?(actionSheet)
        default:
            break
        }
    }, openPeer: { peer in
        presentPeerSettings(peer, {})
    }, removePeer: { peerId in
        removeException(peerId)
    }, revealPeer: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.revealedPeerId) || (peerId != nil && fromPeerId == nil) {
                state.revealedPeerId = peerId
            }
        }
    })

    let signal = combineLatest(statePromise.get(), context.sharedContext.presentationData, ayuExceptionPeers(context: context, refresh: refresh.get()))
    |> map { state, presentationData, exceptions -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let rightNavigationButton: ItemListNavigationButton?
        if exceptions.isEmpty {
            rightNavigationButton = nil
        } else if state.editing {
            rightNavigationButton = ItemListNavigationButton(content: .icon(.done), style: .bold, enabled: true, staysInRow: true, action: {
                updateState { $0.editing = false }
            })
        } else {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                updateState {
                    $0.editing = true
                    $0.revealedPeerId = nil
                }
            })
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.ghostMode)), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ayuGhostEntries(strings: strings, presentationStrings: presentationData.strings, state: state, exceptions: exceptions), style: .blocks, animateChanges: true)
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
