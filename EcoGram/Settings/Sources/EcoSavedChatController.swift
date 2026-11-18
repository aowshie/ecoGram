import Foundation
import UIKit
import QuickLook
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import PresentationDataUtils
import AyuHistory
import EcoStrings

private final class EcoSavedChatArguments {
    let openRecord: (AyuHistoryRecord) -> Void
    let clearChat: () -> Void

    init(openRecord: @escaping (AyuHistoryRecord) -> Void, clearChat: @escaping () -> Void) {
        self.openRecord = openRecord
        self.clearChat = clearChat
    }
}

private enum EcoSavedChatEntry: ItemListNodeEntry {
    case record(index: Int, record: AyuHistoryRecord, header: String, body: String)
    case empty(text: String)
    case clearChat(title: String)

    var section: ItemListSectionId {
        switch self {
        case .record, .empty:
            return 0
        case .clearChat:
            return 1
        }
    }

    var stableId: Int {
        switch self {
        case let .record(index, _, _, _):
            return 10 + index
        case .empty:
            return 0
        case .clearChat:
            return 1_000_000
        }
    }

    static func <(lhs: EcoSavedChatEntry, rhs: EcoSavedChatEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! EcoSavedChatArguments
        switch self {
        case let .record(_, record, header, body):
            return ItemListTextWithLabelItem(presentationData: presentationData, label: header, text: body, style: .blocks, enabledEntityTypes: [], multiline: true, sectionId: self.section, action: {
                arguments.openRecord(record)
            })
        case let .empty(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .clearChat(title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clearChat()
            })
        }
    }
}

private final class EcoMediaPreviewController: QLPreviewController, QLPreviewControllerDataSource {
    private let url: URL

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
        self.dataSource = self
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return self.url as NSURL
    }
}

private func attachmentTitle(_ kind: AyuHistoryAttachment.Kind, strings: EcoStrings) -> String {
    switch kind {
    case .photo:
        return strings.get(.mediaPhoto)
    case .video:
        return strings.get(.mediaVideo)
    case .roundVideo:
        return strings.get(.mediaRoundVideo)
    case .voice:
        return strings.get(.mediaVoice)
    case .audio:
        return strings.get(.mediaAudio)
    case .sticker:
        return strings.get(.mediaSticker)
    case .animation:
        return strings.get(.mediaAnimation)
    case .file:
        return strings.get(.mediaFile)
    case .other:
        return strings.get(.mediaOther)
    }
}

private func recordHeader(_ record: AyuHistoryRecord, strings: EcoStrings, formatter: DateFormatter) -> String {
    let kind = record.kind == .deleted ? strings.get(.savedDeleted) : strings.get(.savedEdited)
    let date = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(record.sentAt)))
    var parts = [kind, date]
    if !record.authorName.isEmpty {
        parts.append(record.authorName)
    }
    return parts.joined(separator: " · ")
}

private func recordBody(_ record: AyuHistoryRecord, strings: EcoStrings) -> String {
    var lines: [String] = []
    switch record.kind {
    case .deleted:
        for attachment in record.attachments {
            var title = attachmentTitle(attachment.kind, strings: strings)
            if let originalName = attachment.originalName, !originalName.isEmpty {
                title += " «\(originalName)»"
            }
            if attachment.storedName != nil {
                title += " · \(ecoFormattedSize(attachment.size))"
            } else if attachment.kind != .other {
                title += " · \(strings.get(.savedMediaNotSaved))"
            }
            lines.append("[\(title)]")
        }
        if !record.text.isEmpty {
            lines.append(record.text)
        }
    case .edited:
        lines.append("\(strings.get(.savedWas)): \(record.text)")
        lines.append("\(strings.get(.savedNow)): \(record.replacementText ?? "")")
    }
    return lines.joined(separator: "\n")
}

func ecoSavedChatController(context: AccountContext, summary: AyuHistoryChatSummary, onChange: @escaping () -> Void) -> ViewController {
    let store = ecoHistoryStore(context: context)
    let recordsPromise = ValuePromise<[AyuHistoryRecord]?>(nil, ignoreRepeated: true)
    let reload: () -> Void = {
        store.records(peerId: summary.peerId) { records in
            recordsPromise.set(records)
        }
    }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short

    var presentControllerImpl: ((ViewController) -> Void)?
    var presentNativeImpl: ((UIViewController) -> Void)?
    var popImpl: (() -> Void)?

    let arguments = EcoSavedChatArguments(openRecord: { record in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        let text = record.kind == .edited ? recordBody(record, strings: strings) : record.text
        if !text.isEmpty {
            items.append(ActionSheetButtonItem(title: strings.get(.savedCopy), action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                UIPasteboard.general.string = text
            }))
        }
        for attachment in record.attachments {
            guard let storedName = attachment.storedName else {
                continue
            }
            let url = store.url(storedName: storedName)
            items.append(ActionSheetButtonItem(title: "\(strings.get(.savedOpenMedia)): \(attachmentTitle(attachment.kind, strings: strings))", action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                presentNativeImpl?(EcoMediaPreviewController(url: url))
            }))
        }
        items.append(ActionSheetButtonItem(title: strings.get(.savedDelete), color: .destructive, action: { [weak actionSheet] in
            actionSheet?.dismissAnimated()
            store.remove(recordIds: [record.id], peerId: summary.peerId) {
                reload()
                onChange()
            }
        }))
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        presentControllerImpl?(actionSheet)
    }, clearChat: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        presentControllerImpl?(textAlertController(context: context, title: nil, text: strings.get(.savedClearChatConfirm), actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .destructiveAction, title: strings.get(.savedDelete), action: {
                store.clear(peerId: summary.peerId) {
                    onChange()
                    popImpl?()
                }
            })
        ]))
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, recordsPromise.get())
    |> map { presentationData, records -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        var entries: [EcoSavedChatEntry] = []
        if let records {
            if records.isEmpty {
                entries.append(.empty(text: strings.get(.savedEmpty)))
            } else {
                for (index, record) in records.enumerated() {
                    entries.append(.record(index: index, record: record, header: recordHeader(record, strings: strings, formatter: formatter), body: recordBody(record, strings: strings)))
                }
                entries.append(.clearChat(title: strings.get(.savedClearChat)))
            }
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(summary.chatTitle), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    presentNativeImpl = { [weak controller] c in
        controller?.view.window?.rootViewController?.present(c, animated: true)
    }
    popImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    reload()
    return controller
}
