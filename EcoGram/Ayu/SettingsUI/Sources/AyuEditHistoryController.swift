import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import ContextUI
import AppBundle
import AyuHistory
import EcoStrings

private struct AyuEditVersion: Equatable {
    let index: Int
    let label: String
    let text: String
}

private enum AyuEditHistoryEntry: ItemListNodeEntry {
    case version(AyuEditVersion)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int {
        switch self {
        case let .version(version):
            return version.index
        }
    }

    static func <(lhs: AyuEditHistoryEntry, rhs: AyuEditHistoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .version(version):
            return ItemListTextWithLabelItem(presentationData: presentationData, label: version.label, text: version.text, style: .blocks, enabledEntityTypes: [], multiline: true, sectionId: self.section, action: nil, longTapAction: {
                UIPasteboard.general.string = version.text
            })
        }
    }
}

private func ayuEditVersions(records: [AyuHistoryRecord], currentText: String, strings: EcoStrings, formatter: DateFormatter) -> [AyuEditVersion] {
    guard let first = records.first else {
        return []
    }
    var versions: [AyuEditVersion] = []
    versions.append(AyuEditVersion(index: 0, label: "\(strings.get(.editOriginal)) · \(formatter.string(from: Date(timeIntervalSince1970: TimeInterval(first.sentAt))))", text: first.text))
    for (offset, record) in records.enumerated() {
        let text = offset == records.count - 1 ? currentText : (record.replacementText ?? "")
        let label = offset == records.count - 1 ? strings.get(.editCurrent) : strings.get(.editEdited)
        versions.append(AyuEditVersion(index: offset + 1, label: "\(label) · \(formatter.string(from: Date(timeIntervalSince1970: TimeInterval(record.savedAt))))", text: text))
    }
    return versions
}

func ayuEditHistoryController(context: AccountContext, records: [AyuHistoryRecord], currentText: String) -> ViewController {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short

    let signal = context.sharedContext.presentationData
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        formatter.locale = Locale(identifier: presentationData.strings.baseLanguageCode)
        let entries = ayuEditVersions(records: records, currentText: currentText, strings: strings, formatter: formatter).map(AyuEditHistoryEntry.version)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.editHistory)), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, ()))
    }
    return ItemListController(context: context, state: signal)
}

public func ayuEditHistoryContextItem(context: AccountContext, messageId: EngineMessage.Id, currentText: String, title: String, push: @escaping (ViewController) -> Void) -> ContextMenuItem? {
    guard messageId.namespace == Namespaces.Message.Cloud else {
        return nil
    }
    let records = ayuHistoryStore(context: context).editRecords(peerId: messageId.peerId.toInt64(), messageId: messageId.id)
    guard !records.isEmpty else {
        return nil
    }
    return .action(ContextMenuActionItem(text: title, icon: { theme in
        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Time"), color: theme.actionSheet.primaryTextColor)
    }, action: { _, f in
        f(.default)
        push(ayuEditHistoryController(context: context, records: records, currentText: currentText))
    }))
}
