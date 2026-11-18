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

    public static let maximumEnabled = 6
    static let enabledByDefault: Set<EcoSelectionAction> = [.delete, .shot, .forward]
}

public enum EcoContextAction: String, CaseIterable {
    case reply
    case copy
    case pin
    case copyLink
    case forward
    case restrict
    case delete
    case selectFromAuthor
    case select
    case editHistory
    case edit
    case translate
    case saveToFiles
    case report
    case viewReplies

    static let enabledByDefault: Set<EcoContextAction> = [.reply, .copy, .pin, .copyLink, .forward, .restrict, .delete, .selectFromAuthor, .select, .editHistory]
}
