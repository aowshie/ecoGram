import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import ItemListPeerItem
import AccountContext
import PresentationDataUtils
import AyuHistory
import EcoStrings

func ecoHistoryStore(context: AccountContext) -> AyuHistoryStore {
    return AyuHistoryStore.store(mediaBoxBasePath: context.account.postbox.mediaBox.basePath)
}

func ecoFormattedSize(_ bytes: Int64) -> String {
    return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

private final class EcoSavedHistoryArguments {
    let context: AccountContext
    let openChat: (AyuHistoryChatSummary) -> Void
    let clearAll: () -> Void

    init(context: AccountContext, openChat: @escaping (AyuHistoryChatSummary) -> Void, clearAll: @escaping () -> Void) {
        self.context = context
        self.openChat = openChat
        self.clearAll = clearAll
    }
}

private enum EcoSavedHistoryEntry: ItemListNodeEntry {
    case chat(index: Int, summary: AyuHistoryChatSummary, peer: EnginePeer?, details: String)
    case empty(text: String)
    case usage(title: String, value: String)
    case clearAll(title: String)

    var section: ItemListSectionId {
        switch self {
        case .chat, .empty:
            return 0
        case .usage, .clearAll:
            return 1
        }
    }

    var stableId: Int {
        switch self {
        case let .chat(index, _, _, _):
            return 10 + index
        case .empty:
            return 0
        case .usage:
            return 1_000_000
        case .clearAll:
            return 1_000_001
        }
    }

    static func <(lhs: EcoSavedHistoryEntry, rhs: EcoSavedHistoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! EcoSavedHistoryArguments
        switch self {
        case let .chat(_, summary, peer, details):
            if let peer {
                return ItemListPeerItem(presentationData: presentationData, systemStyle: .glass, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: .firstLast, context: arguments.context, peer: peer, presence: nil, text: .text(details, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                    arguments.openChat(summary)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
            }
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: summary.chatTitle, label: details, sectionId: self.section, style: .blocks, action: {
                arguments.openChat(summary)
            })
        case let .empty(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .usage(title, value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .clearAll(title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clearAll()
            })
        }
    }
}

private struct EcoSavedHistoryState: Equatable {
    var summaries: [AyuHistoryChatSummary]?
    var peers: [EnginePeer.Id: EnginePeer]
    var usage: Int64
}

private func summaryDetails(_ summary: AyuHistoryChatSummary, strings: EcoStrings) -> String {
    var parts: [String] = []
    if summary.deletedCount > 0 {
        parts.append("\(strings.get(.savedDeleted)): \(summary.deletedCount)")
    }
    if summary.editedCount > 0 {
        parts.append("\(strings.get(.savedEdited)): \(summary.editedCount)")
    }
    return parts.joined(separator: " · ")
}

func ecoSavedHistoryController(context: AccountContext) -> ViewController {
    let store = ecoHistoryStore(context: context)
    let statePromise = ValuePromise(EcoSavedHistoryState(summaries: nil, peers: [:], usage: 0), ignoreRepeated: true)
    let stateValue = Atomic(value: EcoSavedHistoryState(summaries: nil, peers: [:], usage: 0))
    let updateState: ((EcoSavedHistoryState) -> EcoSavedHistoryState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    let peersDisposable = MetaDisposable()

    let reload: () -> Void = {
        store.summaries { summaries in
            updateState { state in
                var state = state
                state.summaries = summaries
                return state
            }
            let peerIds = summaries.map { EnginePeer.Id($0.peerId) }
            peersDisposable.set((context.engine.data.get(EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))))
            |> deliverOnMainQueue).startStrict(next: { peers in
                updateState { state in
                    var state = state
                    var resolved: [EnginePeer.Id: EnginePeer] = [:]
                    for (id, peer) in peers {
                        if let peer {
                            resolved[id] = peer
                        }
                    }
                    state.peers = resolved
                    return state
                }
            }))
        }
        store.usage { usage in
            updateState { state in
                var state = state
                state.usage = usage
                return state
            }
        }
    }

    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let arguments = EcoSavedHistoryArguments(context: context, openChat: { summary in
        pushControllerImpl?(ecoSavedChatController(context: context, summary: summary, onChange: {
            reload()
        }))
    }, clearAll: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        presentControllerImpl?(textAlertController(context: context, title: nil, text: strings.get(.savedClearAllConfirm), actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .destructiveAction, title: strings.get(.savedDelete), action: {
                store.clearAll {
                    reload()
                }
            })
        ]))
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        var entries: [EcoSavedHistoryEntry] = []
        if let summaries = state.summaries {
            if summaries.isEmpty {
                entries.append(.empty(text: strings.get(.savedEmpty)))
            } else {
                for (index, summary) in summaries.enumerated() {
                    entries.append(.chat(index: index, summary: summary, peer: state.peers[EnginePeer.Id(summary.peerId)], details: summaryDetails(summary, strings: strings)))
                }
            }
            entries.append(.usage(title: strings.get(.savedUsage), value: ecoFormattedSize(state.usage)))
            if !summaries.isEmpty {
                entries.append(.clearAll(title: strings.get(.savedClearAll)))
            }
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.savedTitle)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        peersDisposable.dispose()
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    reload()
    return controller
}
