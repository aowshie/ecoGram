import Foundation
import UIKit
import TelegramPresentationData
import AppBundle
import SGStrings
import EcoPreferences
import EcoStrings

struct EcoActionCatalog {
    let strings: PresentationStrings
    let ecoStrings: EcoStrings

    init(strings: PresentationStrings) {
        self.strings = strings
        self.ecoStrings = EcoStrings(languageCode: strings.baseLanguageCode)
    }

    func title(_ action: EcoSelectionAction) -> String {
        switch action {
        case .delete:
            return self.strings.Conversation_ContextMenuDelete
        case .shot:
            return self.ecoStrings.get(.actionShot)
        case .forward:
            return self.strings.Conversation_ContextMenuForward
        case .share:
            return self.strings.Conversation_ContextMenuShare
        case .tag:
            return self.ecoStrings.get(.actionTag)
        case .saveToCloud:
            return self.ecoStrings.get(.actionSaveToCloud)
        case .hideSenderNames:
            return self.strings.Conversation_ForwardOptions_HideSendersNames
        case .report:
            return self.strings.Conversation_ContextMenuReport
        }
    }

    func icon(_ action: EcoSelectionAction) -> UIImage? {
        switch action {
        case .delete:
            return UIImage(bundleImageName: "Chat/Context Menu/Delete")
        case .shot:
            return UIImage(bundleImageName: "Chat/Context Menu/Camera")
        case .forward:
            return UIImage(bundleImageName: "Chat/Context Menu/Forward")
        case .share:
            return UIImage(bundleImageName: "Chat/Context Menu/Share")
        case .tag:
            return UIImage(bundleImageName: "Chat/Context Menu/PriceTag")
        case .saveToCloud:
            return UIImage(bundleImageName: "Chat/Context Menu/Fave")
        case .hideSenderNames:
            return UIImage(bundleImageName: "Chat/Context Menu/User")
        case .report:
            return UIImage(bundleImageName: "Chat/Context Menu/Report")
        }
    }

    func title(_ action: EcoContextAction) -> String {
        switch action {
        case .reply:
            return self.strings.Conversation_ContextMenuReply
        case .copy:
            return self.strings.Conversation_ContextMenuCopy
        case .pin:
            return self.strings.Conversation_Pin
        case .copyLink:
            return self.strings.Conversation_ContextMenuCopyLink
        case .forward:
            return self.strings.Conversation_ContextMenuForward
        case .shot:
            return self.ecoStrings.get(.actionShot)
        case .shotFromHere:
            return self.ecoStrings.get(.shotFromHere)
        case .restrict:
            return self.strings.Conversation_ContextMenuBan
        case .delete:
            return self.strings.Conversation_ContextMenuDelete
        case .selectFromAuthor:
            return i18n("ContextMenu.SelectFromUser", self.strings.baseLanguageCode)
        case .select:
            return self.strings.Conversation_ContextMenuSelect
        case .editHistory:
            return self.ecoStrings.get(.editHistory)
        case .edit:
            return self.strings.Conversation_MessageDialogEdit
        case .translate:
            return self.strings.Conversation_ContextMenuTranslate
        case .saveToFiles:
            return self.strings.Conversation_SaveToFiles
        case .report:
            return self.strings.Conversation_ContextMenuReport
        case .viewReplies:
            return self.strings.Conversation_ContextViewThread
        case .saveToCloud:
            return i18n("ContextMenu.SaveToCloud", self.strings.baseLanguageCode)
        case .hideForwardName:
            return self.strings.NotificationSettings_Stories_CompactHideName
        case .json:
            return "JSON"
        case .sendLogs:
            return "Send Logs"
        }
    }

    func icon(_ action: EcoContextAction) -> UIImage? {
        let name: String
        switch action {
        case .reply:
            name = "Reply"
        case .copy:
            name = "Copy"
        case .pin:
            name = "Pin"
        case .copyLink:
            name = "Link"
        case .forward:
            name = "Forward"
        case .shot, .shotFromHere:
            name = "Camera"
        case .restrict:
            name = "Restrict"
        case .delete:
            name = "Delete"
        case .selectFromAuthor:
            name = "SelectAll"
        case .select:
            name = "Select"
        case .editHistory:
            name = "Time"
        case .edit:
            name = "Edit"
        case .translate:
            name = "Translate"
        case .saveToFiles:
            name = "Save"
        case .report:
            name = "Report"
        case .viewReplies:
            name = "Replies"
        case .saveToCloud:
            name = "Fave"
        case .hideForwardName:
            name = "Forward"
        case .json:
            name = "Settings"
        case .sendLogs:
            name = "Message"
        }
        return UIImage(bundleImageName: "Chat/Context Menu/" + name)
    }
}
