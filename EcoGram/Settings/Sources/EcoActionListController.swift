import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import UndoUI
import EcoPreferences
import EcoStrings

struct EcoActionRow: Equatable {
    let id: String
    let title: String
    let isChecked: Bool
}

final class EcoActionListArguments {
    let icon: (String) -> UIImage?
    let toggle: (String) -> Void

    init(icon: @escaping (String) -> UIImage?, toggle: @escaping (String) -> Void) {
        self.icon = icon
        self.toggle = toggle
    }
}

private enum EcoActionListEntry: ItemListNodeEntry {
    case row(index: Int, row: EcoActionRow)
    case footer(text: String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: String {
        switch self {
        case let .row(_, row):
            return row.id
        case .footer:
            return "footer"
        }
    }

    var sortIndex: Int {
        switch self {
        case let .row(index, _):
            return index
        case .footer:
            return Int.max
        }
    }

    static func <(lhs: EcoActionListEntry, rhs: EcoActionListEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! EcoActionListArguments
        switch self {
        case let .row(_, row):
            return EcoReorderItem(presentationData: presentationData, title: row.title, icon: arguments.icon(row.id), isChecked: row.isChecked, sectionId: self.section, toggle: {
                arguments.toggle(row.id)
            })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

func ecoActionListController(context: AccountContext, title: String, footer: String, rows: @escaping (PresentationStrings) -> [EcoActionRow], icon: @escaping (String) -> UIImage?, toggle: @escaping (String) -> String?, reorder: @escaping ([String]) -> Void) -> ViewController {
    let refresh = ValuePromise<Int>(0, ignoreRepeated: false)
    var revision = 0
    let update: () -> Void = {
        revision += 1
        refresh.set(revision)
    }

    var presentControllerImpl: ((ViewController) -> Void)?
    let arguments = EcoActionListArguments(icon: icon, toggle: { id in
        if let warning = toggle(id) {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: warning, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return true }))
        }
        update()
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, refresh.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [EcoActionListEntry] = rows(presentationData.strings).enumerated().map { index, row in
            return .row(index: index, row: row)
        }
        entries.append(.footer(text: footer))
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.setReorderEntry({ (fromIndex: Int, toIndex: Int, entries: [EcoActionListEntry]) -> Signal<Bool, NoError> in
        var ids: [String] = entries.compactMap { entry in
            if case let .row(_, row) = entry {
                return row.id
            }
            return nil
        }
        guard fromIndex >= 0, fromIndex < ids.count, !ids.isEmpty else {
            return .single(false)
        }
        let targetIndex = min(max(toIndex, 0), ids.count - 1)
        if targetIndex == fromIndex {
            return .single(false)
        }
        let moved = ids.remove(at: fromIndex)
        ids.insert(moved, at: targetIndex)
        reorder(ids)
        update()
        return .single(true)
    })
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

func ecoSelectionPanelController(context: AccountContext) -> ViewController {
    let preferences = EcoPreferences.shared
    let strings = EcoStrings(languageCode: context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode)
    return ecoActionListController(context: context, title: strings.get(.selectionPanel), footer: strings.get(.selectionFooter), rows: { presentationStrings in
        let catalog = EcoActionCatalog(strings: presentationStrings)
        return preferences.selectionOrder.map { action in
            EcoActionRow(id: action.rawValue, title: catalog.title(action), isChecked: preferences.isEnabled(action))
        }
    }, icon: { id in
        let catalog = EcoActionCatalog(strings: context.sharedContext.currentPresentationData.with { $0 }.strings)
        return EcoSelectionAction(rawValue: id).flatMap { catalog.icon($0) }
    }, toggle: { id in
        guard let action = EcoSelectionAction(rawValue: id) else {
            return nil
        }
        return preferences.setEnabled(action, !preferences.isEnabled(action)) ? nil : strings.get(.selectionLimit)
    }, reorder: { ids in
        preferences.setSelectionOrder(ids.compactMap(EcoSelectionAction.init(rawValue:)))
    })
}

func ecoContextMenuController(context: AccountContext) -> ViewController {
    let preferences = EcoPreferences.shared
    let strings = EcoStrings(languageCode: context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode)
    return ecoActionListController(context: context, title: strings.get(.contextMenu), footer: strings.get(.contextFooter), rows: { presentationStrings in
        let catalog = EcoActionCatalog(strings: presentationStrings)
        return preferences.contextOrder.map { action in
            EcoActionRow(id: action.rawValue, title: catalog.title(action), isChecked: preferences.isEnabled(action))
        }
    }, icon: { id in
        let catalog = EcoActionCatalog(strings: context.sharedContext.currentPresentationData.with { $0 }.strings)
        return EcoContextAction(rawValue: id).flatMap { catalog.icon($0) }
    }, toggle: { id in
        if let action = EcoContextAction(rawValue: id) {
            preferences.setEnabled(action, !preferences.isEnabled(action))
        }
        return nil
    }, reorder: { ids in
        preferences.setContextOrder(ids.compactMap(EcoContextAction.init(rawValue:)))
    })
}
