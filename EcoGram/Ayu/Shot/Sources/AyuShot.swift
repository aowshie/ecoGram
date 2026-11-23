import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import Display
import AccountContext

private let ayuShotMessageLimit = 40
private let ayuShotMaximumWidth: CGFloat = 430.0

public func ayuPresentShot(context: AccountContext, messageIds: [EngineMessage.Id], sourceView: UIView) {
    guard let window = sourceView.window else {
        return
    }
    let renderWidth = min(window.bounds.width, ayuShotMaximumWidth)
    let _ = (ayuShotGroups(context: context, messageIds: messageIds)
    |> deliverOnMainQueue).startStandalone(next: { groups in
        guard !groups.isEmpty else {
            return
        }
        let renderer = AyuShotRenderer(context: context, groups: groups, revealsProtectedContent: !ecoCaptureProtection(true))
        (context.sharedContext.mainWindow?.viewController as? NavigationController)?.pushViewController(ayuShotScreen(context: context, renderer: renderer, renderWidth: renderWidth))
    })
}

public func ayuShotImage(context: AccountContext, messageIds: [EngineMessage.Id], parentView: UIView) -> Signal<UIImage?, NoError> {
    return ayuShotGroups(context: context, messageIds: messageIds)
    |> deliverOnMainQueue
    |> mapToSignal { [weak parentView] groups -> Signal<UIImage?, NoError> in
        guard let parentView, let window = parentView.window, !groups.isEmpty else {
            return .single(nil)
        }
        return Signal { subscriber in
            let renderer = AyuShotRenderer(context: context, groups: groups, revealsProtectedContent: !ecoCaptureProtection(true))
            renderer.render(in: parentView, width: min(window.bounds.width, ayuShotMaximumWidth), options: AyuShotOptions(showBackground: true, showDate: AyuShotOptions.stored.showDate), completion: { image in
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

private func ayuShotGroups(context: AccountContext, messageIds: [EngineMessage.Id]) -> Signal<[[EngineMessage]], NoError> {
    guard !messageIds.isEmpty else {
        return .single([])
    }
    return context.engine.data.get(EngineDataList(messageIds.map(TelegramEngine.EngineData.Item.Messages.Message.init(id:))))
    |> map { messages -> [[EngineMessage]] in
        let sorted = messages.compactMap { $0 }.sorted(by: { $0.index < $1.index })
        var groups: [[EngineMessage]] = []
        for message in sorted.suffix(ayuShotMessageLimit) {
            if let groupingKey = message.groupingKey, let last = groups.last?.last, last.groupingKey == groupingKey {
                groups[groups.count - 1].append(message)
            } else {
                groups.append([message])
            }
        }
        return groups
    }
}
