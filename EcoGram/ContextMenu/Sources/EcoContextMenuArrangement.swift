import Foundation
import ContextUI
import TelegramPresentationData
import SGStrings
import EcoPreferences
import EcoStrings

private func ecoContextAction(title: String, strings: PresentationStrings) -> EcoContextAction? {
    switch title {
    case strings.Conversation_ContextMenuReply:
        return .reply
    case strings.Conversation_ContextMenuCopy:
        return .copy
    case strings.Conversation_Pin, strings.Conversation_Unpin:
        return .pin
    case strings.Conversation_ContextMenuCopyLink:
        return .copyLink
    case strings.Conversation_ContextMenuForward:
        return .forward
    case strings.Conversation_ContextMenuBan:
        return .restrict
    case strings.Conversation_ContextMenuDelete, strings.Chat_MessageContextMenu_Remove, strings.Conversation_ContextMenuCancelSending, strings.Conversation_ContextMenuCancelEditing:
        return .delete
    case i18n("ContextMenu.SelectFromUser", strings.baseLanguageCode):
        return .selectFromAuthor
    case strings.Conversation_ContextMenuSelect:
        return .select
    case EcoStrings(languageCode: strings.baseLanguageCode).get(.editHistory):
        return .editHistory
    case strings.Conversation_MessageDialogEdit:
        return .edit
    case strings.Conversation_ContextMenuTranslate:
        return .translate
    case strings.Conversation_SaveToFiles:
        return .saveToFiles
    case strings.Conversation_ContextMenuReport:
        return .report
    case strings.Conversation_ContextViewThread:
        return .viewReplies
    case i18n("ContextMenu.SaveToCloud", strings.baseLanguageCode):
        return .saveToCloud
    case strings.NotificationSettings_Stories_CompactHideName:
        return .hideForwardName
    case "JSON":
        return .json
    case "Send Logs":
        return .sendLogs
    default:
        return nil
    }
}

private func ecoTrimmedSeparators(_ items: [ContextMenuItem]) -> [ContextMenuItem] {
    var result: [ContextMenuItem] = []
    for item in items {
        if case .separator = item {
            if result.isEmpty {
                continue
            }
            if case .separator = result[result.count - 1] {
                continue
            }
        }
        result.append(item)
    }
    while let last = result.last, case .separator = last {
        result.removeLast()
    }
    return result
}

public func ecoArrangeContextMenu(actions: inout [ContextMenuItem], sgActions: inout [ContextMenuItem], strings: PresentationStrings) {
    let preferences = EcoPreferences.shared
    var known: [EcoContextAction: ContextMenuItem] = [:]
    var others: [ContextMenuItem] = []
    for item in actions {
        if case let .action(action) = item, let kind = ecoContextAction(title: action.text, strings: strings) {
            if known[kind] == nil {
                known[kind] = item
            }
        } else {
            others.append(item)
        }
    }
    for item in sgActions {
        if case let .action(action) = item, let kind = ecoContextAction(title: action.text, strings: strings), known[kind] == nil {
            known[kind] = item
        }
    }
    sgActions = []
    var arranged: [ContextMenuItem] = []
    for kind in preferences.contextOrder {
        if let item = known[kind], preferences.isEnabled(kind) {
            arranged.append(item)
        }
    }
    let rest = ecoTrimmedSeparators(others)
    if !arranged.isEmpty && !rest.isEmpty {
        arranged.append(.separator)
    }
    actions = arranged + rest
}
