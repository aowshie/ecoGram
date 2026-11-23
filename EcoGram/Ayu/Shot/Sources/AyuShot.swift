import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import Display
import AccountContext
import UndoUI
import EcoStrings

public let ayuShotMessageLimit = 100
private let ayuShotMaximumWidth: CGFloat = 430.0

private struct AyuShotSelection {
    let groups: [[EngineMessage]]
    let isTruncated: Bool
}

public func ayuPresentShot(context: AccountContext, messageIds: [EngineMessage.Id], sourceView: UIView) {
    guard let window = sourceView.window else {
        return
    }
    let renderWidth = min(window.bounds.width, ayuShotMaximumWidth)
    let _ = (ayuShotSelection(context: context, messageIds: messageIds)
    |> deliverOnMainQueue).startStandalone(next: { selection in
        guard !selection.groups.isEmpty else {
            return
        }
        let renderer = AyuShotRenderer(context: context, groups: selection.groups, revealsProtectedContent: !ecoCaptureProtection(true))
        (context.sharedContext.mainWindow?.viewController as? NavigationController)?.pushViewController(ayuShotScreen(context: context, renderer: renderer, renderWidth: renderWidth))
        if selection.isTruncated {
            ayuPresentShotLimitToast(context: context)
        }
    })
}

public func ayuShotImage(context: AccountContext, messageIds: [EngineMessage.Id], parentView: UIView) -> Signal<UIImage?, NoError> {
    return ayuShotSelection(context: context, messageIds: messageIds)
    |> deliverOnMainQueue
    |> mapToSignal { [weak parentView] selection -> Signal<UIImage?, NoError> in
        guard let parentView, let window = parentView.window, !selection.groups.isEmpty else {
            return .single(nil)
        }
        if selection.isTruncated {
            ayuPresentShotLimitToast(context: context)
        }
        return Signal { subscriber in
            let renderer = AyuShotRenderer(context: context, groups: selection.groups, revealsProtectedContent: !ecoCaptureProtection(true))
            var options = AyuShotOptions.stored
            options.showBackground = true
            renderer.render(in: parentView, width: min(window.bounds.width, ayuShotMaximumWidth), options: options, completion: { image in
                subscriber.putNext(image)
                subscriber.putCompletion()
            })
            return ActionDisposable {
                Queue.mainQueue().async {
                    renderer.cancel()
                }
            }
        }
    }
}

private func ayuPresentShotLimitToast(context: AccountContext) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let text = String(format: EcoStrings(languageCode: presentationData.strings.baseLanguageCode).get(.shotLimit), ayuShotMessageLimit)
    context.sharedContext.mainWindow?.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, position: .top, action: { _ in
        return false
    }), on: .root)
}

private func ayuShotSelection(context: AccountContext, messageIds: [EngineMessage.Id]) -> Signal<AyuShotSelection, NoError> {
    guard !messageIds.isEmpty else {
        return .single(AyuShotSelection(groups: [], isTruncated: false))
    }
    return context.engine.data.get(EngineDataList(messageIds.map(TelegramEngine.EngineData.Item.Messages.Message.init(id:))))
    |> map { messages -> AyuShotSelection in
        let sorted = messages.compactMap { $0 }.sorted(by: { $0.index < $1.index })
        var groups: [[EngineMessage]] = []
        for message in sorted.prefix(ayuShotMessageLimit) {
            if let groupingKey = message.groupingKey, let last = groups.last?.last, last.groupingKey == groupingKey {
                groups[groups.count - 1].append(message)
            } else {
                groups.append([message])
            }
        }
        return AyuShotSelection(groups: groups, isTruncated: sorted.count > ayuShotMessageLimit)
    }
}
