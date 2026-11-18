import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext

final class AyuShotRenderer {
    private static let padding: CGFloat = 12.0
    private static let spacing: CGFloat = 2.0

    private let context: AccountContext
    private let groups: [[EngineMessage]]
    private let containerNode: ASDisplayNode
    private let messagesNode: ASDisplayNode

    init(context: AccountContext, groups: [[EngineMessage]]) {
        self.context = context
        self.groups = groups
        self.containerNode = ASDisplayNode()
        self.containerNode.displaysAsynchronously = false
        self.messagesNode = ASDisplayNode()
        self.messagesNode.displaysAsynchronously = false
        self.messagesNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        self.containerNode.addSubnode(self.messagesNode)
    }

    func render(in parentView: UIView, width: CGFloat, completion: @escaping (UIImage?) -> Void) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        parentView.addSubview(self.containerNode.view)
        let size = self.layout(presentationData: presentationData, width: width)
        guard size.height > 0.0 else {
            self.containerNode.view.removeFromSuperview()
            completion(nil)
            return
        }
        let background = AyuShotRenderer.backgroundColor(presentationData: presentationData)
        Queue.mainQueue().after(0.6) {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3.0
            format.opaque = true
            let bounds = CGRect(origin: .zero, size: size)
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                background.setFill()
                UIRectFill(bounds)
                self.containerNode.view.drawHierarchy(in: bounds, afterScreenUpdates: true)
            }
            self.containerNode.view.removeFromSuperview()
            completion(image)
        }
    }

    private func layout(presentationData: PresentationData, width: CGFloat) -> CGSize {
        let theme = presentationData.theme.withUpdated(preview: true)
        let items: [ListViewItem] = self.groups.map { messages in
            return self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: messages, theme: theme, strings: presentationData.strings, wallpaper: presentationData.chatWallpaper, fontSize: presentationData.chatFontSize, chatBubbleCorners: presentationData.chatBubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: nil, availableReactions: nil, accountPeer: nil, isCentered: false, isPreview: true, isStandalone: false, rank: nil, rankRole: nil, isGiftMessageComposerPreview: false, activateGiftMessageInput: nil)
        }
        let params = ListViewItemLayoutParams(width: width, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0)
        var nodes: [ListViewItemNode] = []
        for item in items {
            var itemNode: ListViewItemNode?
            item.nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: true, neighbors: ListViewItemNeighbors(previous: nil, next: nil), completion: { node, apply in
                itemNode = node
                apply().1(ListViewItemApply())
            })
            if let itemNode {
                itemNode.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                itemNode.isUserInteractionEnabled = false
                nodes.append(itemNode)
                self.messagesNode.addSubnode(itemNode)
            }
        }
        var offset = AyuShotRenderer.padding
        for itemNode in nodes.reversed() {
            let height = itemNode.contentSize.height + itemNode.insets.top + itemNode.insets.bottom
            itemNode.frame = CGRect(origin: CGPoint(x: 0.0, y: offset), size: CGSize(width: width, height: height))
            offset += height + AyuShotRenderer.spacing
        }
        let size = CGSize(width: width, height: nodes.isEmpty ? 0.0 : offset - AyuShotRenderer.spacing + AyuShotRenderer.padding)
        for itemNode in nodes {
            itemNode.updateFrame(itemNode.frame, within: size)
        }
        self.containerNode.frame = CGRect(origin: CGPoint(x: -10000.0, y: 0.0), size: size)
        self.messagesNode.frame = CGRect(origin: .zero, size: size)
        return size
    }

    private static func backgroundColor(presentationData: PresentationData) -> UIColor {
        switch presentationData.chatWallpaper {
        case let .color(color):
            return UIColor(rgb: color)
        case let .gradient(gradient):
            if let color = gradient.colors.first {
                return UIColor(rgb: color)
            }
        case let .file(file):
            if let color = file.settings.colors.first {
                return UIColor(rgb: color)
            }
        default:
            break
        }
        return presentationData.theme.list.blocksBackgroundColor
    }
}
