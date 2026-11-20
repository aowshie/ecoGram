import Foundation
import UIKit
import Display
import SwiftSignalKit
import ComponentFlow
import AccountContext
import AppBundle
import AlertComponent
import AlertHeaderComponent
import AyuSettings
import AyuBadges
import EcoBadges
import EcoPreferences
import EcoStrings

private func ecoBadgeSourceTitle(_ source: EcoBadgeSource, strings: EcoStrings) -> String {
    switch source {
    case .telegram:
        return strings.get(.badgesTelegram)
    case .ayugram:
        return strings.get(.ayuTitle)
    case .ecogram:
        return strings.get(.settingsTitle)
    }
}

private func ecoBadgeSourceIcon(_ source: EcoBadgeSource) -> UIImage? {
    switch source {
    case .telegram:
        return UIImage(bundleImageName: "Chat List/PeerPremiumIcon")
    case .ayugram:
        return AyuBadgeImages.image(.official, side: 22.0)
    case .ecogram:
        return EcoBadgeImages.image(.developer, side: 22.0)
    }
}

private func ecoBadgeSourceEnabled(_ source: EcoBadgeSource) -> Bool {
    switch source {
    case .telegram:
        return true
    case .ayugram:
        return AyuSettings.shared.showAyuBadges
    case .ecogram:
        return EcoPreferences.shared.showEcoBadges
    }
}

public func ecoBadgesController(context: AccountContext) -> ViewController {
    let preferences = EcoPreferences.shared
    let strings = EcoStrings(languageCode: context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode)
    return ecoActionListController(context: context, title: strings.get(.badgesTitle), footer: strings.get(.badgesFooter), rows: { _ in
        return preferences.badgeOrder.map { source in
            EcoActionRow(id: source.rawValue, title: ecoBadgeSourceTitle(source, strings: strings), isChecked: ecoBadgeSourceEnabled(source))
        }
    }, icon: { id in
        return EcoBadgeSource(rawValue: id).flatMap(ecoBadgeSourceIcon)
    }, toggle: { id in
        switch EcoBadgeSource(rawValue: id) {
        case .telegram:
            return strings.get(.badgesTelegramLocked)
        case .ayugram:
            AyuSettings.shared.showAyuBadges = !AyuSettings.shared.showAyuBadges
        case .ecogram:
            preferences.showEcoBadges = !preferences.showEcoBadges
        case .none:
            break
        }
        return nil
    }, reorder: { ids in
        preferences.setBadgeOrder(ids.compactMap(EcoBadgeSource.init(rawValue:)))
    })
}

private let ecoEarlyAlertSettleDelay: Double = 0.6

public func ecoClaimEarlyBadge(context: AccountContext, ready: Signal<Bool, NoError>, present: @escaping (ViewController) -> Void, push: @escaping (ViewController) -> Void) {
    let presentWhenReady: () -> Void = {
        let _ = (ready
        |> filter { $0 }
        |> take(1)
        |> delay(ecoEarlyAlertSettleDelay, queue: .mainQueue())).startStandalone(next: { _ in
            guard EcoBadges.shared.hasPendingEarlyAlert else {
                return
            }
            present(ecoEarlyBadgeAlert(context: context, openSettings: {
                push(ecoBadgesController(context: context))
            }))
        })
    }
    if EcoBadges.shared.hasPendingEarlyAlert {
        presentWhenReady()
        return
    }
    EcoBadges.shared.claimEarlyBadge(telegramId: context.account.peerId.id._internalGetInt64Value(), completion: { isEarlyUser in
        if isEarlyUser {
            presentWhenReady()
        }
    })
}

private func ecoEarlyBadgeAlert(context: AccountContext, openSettings: @escaping () -> Void) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
    let iconSize = CGSize(width: 64.0, height: 64.0)
    let content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = [
        AnyComponentWithIdentity(id: "header", component: AnyComponent(AlertHeaderComponent(component: AnyComponentWithIdentity(id: "badge", component: AnyComponent(Image(image: EcoBadgeImages.image(.early, side: iconSize.width), tintColor: presentationData.theme.actionSheet.controlAccentColor, size: iconSize)))))),
        AnyComponentWithIdentity(id: "title", component: AnyComponent(AlertTitleComponent(title: strings.get(.earlyBadgeTitle), alignment: .center))),
        AnyComponentWithIdentity(id: "text", component: AnyComponent(AlertTextComponent(content: .plain(strings.get(.earlyBadgeText)), alignment: .center)))
    ]
    return AlertScreen(context: context, configuration: AlertScreen.Configuration(dismissOnOutsideTap: false), content: content, actions: [
        AlertScreen.Action(title: strings.get(.earlyBadgeOpen), type: .generic, action: {
            EcoBadges.shared.markEarlyAlertShown()
            openSettings()
        }),
        AlertScreen.Action(title: presentationData.strings.Common_OK, type: .default, action: {
            EcoBadges.shared.markEarlyAlertShown()
        })
    ])
}
