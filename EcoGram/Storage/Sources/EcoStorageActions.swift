import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ContextUI
import AyuSettings
import EcoStrings

private let ecoCleanedAccounts = Atomic<Set<EnginePeer.Id>>(value: Set())

public func ecoUsageTitle(strings: PresentationStrings) -> String {
    return EcoStrings(languageCode: strings.baseLanguageCode).get(.usageTitle)
}

public func ecoStorageLaunchCleanup(context: AccountContext) {
    var isFirstLaunch = false
    let _ = ecoCleanedAccounts.modify { accounts in
        var accounts = accounts
        isFirstLaunch = accounts.insert(context.account.peerId).inserted
        return accounts
    }
    guard isFirstLaunch else {
        return
    }
    context.engine.messages.ayuPrepareHistory()
    if AyuSettings.shared.clearHistoryOnLaunch {
        let _ = context.engine.messages.ayuClearKept(categories: Set(AyuKeptCategory.allCases)).startStandalone()
    } else {
        ecoExpireKept(context: context)
    }
}

func ecoExpireKept(context: AccountContext) {
    let days = AyuSettings.shared.historyCleanupDays
    guard days > 0 else {
        return
    }
    let threshold = Int32(Date().timeIntervalSince1970) - Int32(days * 24 * 60 * 60)
    let _ = context.engine.messages.ayuExpireKept(olderThan: threshold).startStandalone()
}

final class EcoUsageContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: mainWindowScreenBounds, insets: UIEdgeInsets(top: -4.0, left: 0.0, bottom: -4.0, right: 0.0))
    }
}
