import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import EcoStrings

private var activeRenderer: AyuShotRenderer?

public func ayuPresentShot(context: AccountContext, messageIds: [EngineMessage.Id], sourceView: UIView) {
    guard let window = sourceView.window, !messageIds.isEmpty, activeRenderer == nil else {
        return
    }
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
    let _ = (context.engine.data.get(EngineDataList(messageIds.map(TelegramEngine.EngineData.Item.Messages.Message.init(id:))))
    |> deliverOnMainQueue).startStandalone(next: { [weak window] messages in
        guard let window else {
            return
        }
        let sorted = messages.compactMap { $0 }.sorted(by: { $0.index < $1.index })
        let groups = ayuShotGroups(Array(sorted.suffix(40)))
        guard !groups.isEmpty else {
            return
        }
        let renderer = AyuShotRenderer(context: context, groups: groups)
        activeRenderer = renderer
        renderer.render(in: window, width: min(window.bounds.width, 430.0), completion: { image in
            activeRenderer = nil
            var presenter = window.rootViewController
            while let presented = presenter?.presentedViewController {
                presenter = presented
            }
            guard let image else {
                let alert = UIAlertController(title: nil, message: strings.get(.shotFailed), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: presentationData.strings.Common_OK, style: .default))
                presenter?.present(alert, animated: true)
                return
            }
            presenter?.present(AyuShotPreviewController(image: image, strings: strings), animated: true)
        })
    })
}

private func ayuShotGroups(_ messages: [EngineMessage]) -> [[EngineMessage]] {
    var groups: [[EngineMessage]] = []
    for message in messages {
        if let groupingKey = message.groupingKey, let last = groups.last?.last, last.groupingKey == groupingKey {
            groups[groups.count - 1].append(message)
        } else {
            groups.append([message])
        }
    }
    return groups
}
