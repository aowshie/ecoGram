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
    private static let avatarSpacing: CGFloat = 8.0

    private let context: AccountContext
    private let groups: [[EngineMessage]]
    private let containerNode: ASDisplayNode
    private let messagesNode: ASDisplayNode

    init(context: AccountContext, groups: [[EngineMessage]]) {
        self.context = context
        self.groups = groups.map { $0.map(AyuShotRenderer.asGroupMessage) }
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
        Queue.mainQueue().after(0.8) {
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

    private static func asGroupMessage(_ message: EngineMessage) -> EngineMessage {
        let raw = message._asMessage()
        guard raw.id.peerId.namespace == Namespaces.Peer.CloudUser || raw.id.peerId.namespace == Namespaces.Peer.SecretChat else {
            return message
        }
        let groupId = EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: raw.id.peerId.id)
        let group = TelegramGroup(id: groupId, title: "", photo: [], participantCount: 2, role: .member, membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
        var peers = raw.peers
        peers[groupId] = group
        let updated = raw.withUpdatedId(id: EngineMessage.Id(peerId: groupId, namespace: raw.id.namespace, id: raw.id.id)).withUpdatedPeers(peers)
        return EngineMessage(updated)
    }

    private func layout(presentationData: PresentationData, width: CGFloat) -> CGSize {
        let theme = presentationData.theme.withUpdated(preview: true)
        let accountPeerId = self.context.account.peerId
        let items: [ListViewItem] = self.groups.map { messages in
            return self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: messages, theme: theme, strings: presentationData.strings, wallpaper: presentationData.chatWallpaper, fontSize: presentationData.chatFontSize, chatBubbleCorners: presentationData.chatBubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: nil, availableReactions: nil, accountPeer: nil, isCentered: false, isPreview: true, isStandalone: false, rank: nil, rankRole: nil, isGiftMessageComposerPreview: false, activateGiftMessageInput: nil)
        }
        let params = ListViewItemLayoutParams(width: width, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0)
        var nodes: [ListViewItemNode] = []
        for (index, item) in items.enumerated() {
            let previous = index == 0 ? nil : items[index - 1].neighborDescriptor
            let next = index == items.count - 1 ? nil : items[index + 1].neighborDescriptor
            var itemNode: ListViewItemNode?
            item.nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: true, neighbors: ListViewItemNeighbors(previous: previous, next: next), completion: { node, apply in
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
        guard nodes.count == self.groups.count else {
            return .zero
        }

        var frames: [CGRect] = Array(repeating: .zero, count: nodes.count)
        var offset = AyuShotRenderer.padding
        for index in (0 ..< nodes.count).reversed() {
            let itemNode = nodes[index]
            let height = itemNode.contentSize.height + itemNode.insets.top + itemNode.insets.bottom
            frames[index] = CGRect(origin: CGPoint(x: 0.0, y: offset), size: CGSize(width: width, height: height))
            offset += height + AyuShotRenderer.spacing
        }
        let size = CGSize(width: width, height: offset - AyuShotRenderer.spacing + AyuShotRenderer.padding)
        for (index, itemNode) in nodes.enumerated() {
            itemNode.frame = frames[index]
            itemNode.updateFrame(itemNode.frame, within: size)
        }

        for index in 0 ..< self.groups.count {
            guard let message = self.groups[index].first, let author = message.author, message._asMessage().effectivelyIncoming(accountPeerId) else {
                continue
            }
            let nextAuthorId = index + 1 < self.groups.count ? self.groups[index + 1].first?.author?.id : nil
            if nextAuthorId == author.id {
                continue
            }
            let header = self.context.sharedContext.makeChatMessageAvatarHeaderItem(context: self.context, timestamp: message.timestamp, peer: author, message: message, theme: theme, strings: presentationData.strings, wallpaper: presentationData.chatWallpaper, fontSize: presentationData.chatFontSize, chatBubbleCorners: presentationData.chatBubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder)
            let headerNode = header.node(synchronousLoad: true)
            headerNode.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            self.messagesNode.addSubnode(headerNode)
            headerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: frames[index].minY + 3.0), size: CGSize(width: width, height: header.height))
            headerNode.updateLayout(size: size, leftInset: 0.0, rightInset: 0.0, transition: .immediate)
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
