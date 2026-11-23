import Foundation

public enum EcoSelectionAction: String, CaseIterable {
    case delete
    case shot
    case forward
    case share
    case tag
    case saveToCloud
    case hideSenderNames
    case report

    public static let maximumEnabled = 5
    static let enabledByDefault: Set<EcoSelectionAction> = [.delete, .shot, .forward]
}

public enum EcoContextAction: String, CaseIterable {
    case reply
    case copy
    case saveToFiles
    case pin
    case copyLink
    case forward
    case shot
    case restrict
    case delete
    case selectFromAuthor
    case select
    case editHistory
    case edit
    case translate
    case report
    case viewReplies
    case saveToCloud
    case hideForwardName
    case json
    case sendLogs

    static let enabledByDefault: Set<EcoContextAction> = [.reply, .copy, .pin, .copyLink, .forward, .shot, .restrict, .delete, .selectFromAuthor, .select, .editHistory]
}
