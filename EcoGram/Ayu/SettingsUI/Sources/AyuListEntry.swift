import Foundation
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
import ItemListUI
import ItemListPeerItem
import ItemListPeerActionItem
import AccountContext
import SettingsUI

enum AyuListAction: Hashable {
    case openGhost
    case openHistory
    case addException
    case deleteExceptions
}

final class AyuListArguments {
    let context: AccountContext
    let toggle: (String, Bool) -> Void
    let perform: (AyuListAction) -> Void
    let openPeer: (EnginePeer) -> Void
    let removePeer: (EnginePeer.Id) -> Void

    init(context: AccountContext, toggle: @escaping (String, Bool) -> Void, perform: @escaping (AyuListAction) -> Void, openPeer: @escaping (EnginePeer) -> Void = { _ in }, removePeer: @escaping (EnginePeer.Id) -> Void = { _ in }) {
        self.context = context
        self.toggle = toggle
        self.perform = perform
        self.openPeer = openPeer
        self.removePeer = removePeer
    }
}

enum AyuListEntry: ItemListNodeEntry {
    case header(section: Int32, order: Int, text: String)
    case category(section: Int32, order: Int, action: AyuListAction, title: String, subtitle: String, label: String)
    case toggle(section: Int32, order: Int, key: String, title: String, value: Bool, enabled: Bool)
    case notice(section: Int32, order: Int, text: String)
    case peerAction(section: Int32, order: Int, action: AyuListAction, title: String)
    case peer(section: Int32, order: Int, peer: EnginePeer, value: String)
    case destructive(section: Int32, order: Int, action: AyuListAction, title: String)

    var section: ItemListSectionId {
        switch self {
        case let .header(section, _, _), let .category(section, _, _, _, _, _), let .toggle(section, _, _, _, _, _), let .notice(section, _, _), let .peerAction(section, _, _, _), let .peer(section, _, _, _), let .destructive(section, _, _, _):
            return section
        }
    }

    var order: Int {
        switch self {
        case let .header(_, order, _), let .category(_, order, _, _, _, _), let .toggle(_, order, _, _, _, _), let .notice(_, order, _), let .peerAction(_, order, _, _), let .peer(_, order, _, _), let .destructive(_, order, _, _):
            return order
        }
    }

    var stableId: String {
        switch self {
        case let .header(section, _, _):
            return "header.\(section)"
        case let .category(_, _, action, _, _, _):
            return "category.\(action)"
        case let .toggle(_, _, key, _, _, _):
            return "toggle." + key
        case let .notice(section, _, _):
            return "notice.\(section)"
        case let .peerAction(_, _, action, _):
            return "peerAction.\(action)"
        case let .peer(_, _, peer, _):
            return "peer\(peer.id.toInt64())"
        case let .destructive(_, _, action, _):
            return "destructive.\(action)"
        }
    }

    static func < (lhs: AyuListEntry, rhs: AyuListEntry) -> Bool {
        return lhs.order < rhs.order
    }

    static func == (lhs: AyuListEntry, rhs: AyuListEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.header(a1, a2, a3), .header(b1, b2, b3)):
            return a1 == b1 && a2 == b2 && a3 == b3
        case let (.category(a1, a2, a3, a4, a5, a6), .category(b1, b2, b3, b4, b5, b6)):
            return a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5 && a6 == b6
        case let (.toggle(a1, a2, a3, a4, a5, a6), .toggle(b1, b2, b3, b4, b5, b6)):
            return a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4 && a5 == b5 && a6 == b6
        case let (.notice(a1, a2, a3), .notice(b1, b2, b3)):
            return a1 == b1 && a2 == b2 && a3 == b3
        case let (.peerAction(a1, a2, a3, a4), .peerAction(b1, b2, b3, b4)):
            return a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4
        case let (.peer(a1, a2, a3, a4), .peer(b1, b2, b3, b4)):
            return a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4
        case let (.destructive(a1, a2, a3, a4), .destructive(b1, b2, b3, b4)):
            return a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4
        default:
            return false
        }
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyuListArguments
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .category(_, _, action, title, subtitle, label):
            return NotificationsCategoryItemListItem(presentationData: presentationData, systemStyle: .glass, title: title, subtitle: subtitle, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.perform(action)
            })
        case let .toggle(_, _, key, title, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, enabled: enabled, maximumNumberOfLines: 0, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case let .notice(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .peerAction(_, _, action, title):
            return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.addPersonIcon(presentationData.theme), title: title, alwaysPlain: true, sectionId: self.section, editing: false, action: {
                arguments.perform(action)
            })
        case let .peer(_, _, peer, value):
            let presentation = arguments.context.sharedContext.currentPresentationData.with { $0 }
            return ItemListPeerItem(presentationData: presentationData, systemStyle: .glass, dateTimeFormat: presentation.dateTimeFormat, nameDisplayOrder: presentation.nameDisplayOrder, context: arguments.context, peer: peer, presence: nil, text: .text(value, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: nil), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                arguments.openPeer(peer)
            }, setPeerIdWithRevealedOptions: { _, _ in
            }, removePeer: { peerId in
                arguments.removePeer(peerId)
            }, hasTopStripe: false)
        case let .destructive(_, _, action, title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.perform(action)
            })
        }
    }
}
