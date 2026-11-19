import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import Display
import AccountContext

public func ayuPresentShot(context: AccountContext, messageIds: [EngineMessage.Id], sourceView: UIView) {
    guard let window = sourceView.window, !messageIds.isEmpty else {
        return
    }
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
        context.sharedContext.mainWindow?.present(AyuShotPreviewController(context: context, renderer: renderer, renderWidth: min(window.bounds.width, 430.0)), on: .root)
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
