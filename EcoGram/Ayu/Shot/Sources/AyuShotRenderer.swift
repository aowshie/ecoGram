import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import WallpaperBackgroundNode
import AyuBadges

struct AyuShotOptions: Hashable {
    var showBackground: Bool
    var showDate: Bool
}

final class AyuShotRenderer {
    private static let ownAliasOffset: Int64 = 1 << 48

    private let context: AccountContext
    private let groups: [[EngineMessage]]
    private var pass: AyuShotRenderPass?

    init(context: AccountContext, groups: [[EngineMessage]]) {
        self.context = context
        let accountPeerId = context.account.peerId
        let ownAlias = AyuShotRenderer.ownAlias(context: context, groups: groups)
        self.groups = groups.map { messages in
            return messages.map { AyuShotRenderer.prepare($0, accountPeerId: accountPeerId, ownAlias: ownAlias) }
        }
    }

    func render(in parentView: UIView, width: CGFloat, options: AyuShotOptions, completion: @escaping (UIImage?) -> Void) {
        guard self.pass == nil else {
            completion(nil)
            return
        }
        let pass = AyuShotRenderPass(context: self.context, groups: self.groups, options: options)
        self.pass = pass
        pass.render(in: parentView, width: width, completion: { [weak self] image in
            self?.pass = nil
            completion(image)
        })
    }

    private static func ownAlias(context: AccountContext, groups: [[EngineMessage]]) -> TelegramUser? {
        let accountPeerId = context.account.peerId
        for messages in groups {
            for message in messages {
                if let author = message._asMessage().author as? TelegramUser, author.id == accountPeerId {
                    let rawId = accountPeerId.id._internalGetInt64Value()
                    let aliasRawId = rawId + AyuShotRenderer.ownAliasOffset
                    AyuBadges.shared.registerAlias(aliasRawId, for: rawId)
                    let aliasId = EnginePeer.Id(namespace: accountPeerId.namespace, id: EnginePeer.Id.Id._internalFromInt64Value(aliasRawId))
                    return TelegramUser(id: aliasId, accessHash: author.accessHash, firstName: author.firstName, lastName: author.lastName, username: author.username, phone: nil, photo: author.photo, botInfo: nil, restrictionInfo: nil, flags: author.flags, emojiStatus: author.emojiStatus, usernames: author.usernames, storiesHidden: author.storiesHidden, nameColor: author.nameColor, backgroundEmojiId: author.backgroundEmojiId, profileColor: author.profileColor, profileBackgroundEmojiId: author.profileBackgroundEmojiId, subscriberCount: nil, verificationIconFileId: author.verificationIconFileId)
                }
            }
        }
        return nil
    }

    private static func prepare(_ message: EngineMessage, accountPeerId: EnginePeer.Id, ownAlias: TelegramUser?) -> EngineMessage {
        var raw = message._asMessage()
        var peers = raw.peers
        if let ownAlias, raw.author?.id == accountPeerId {
            peers[ownAlias.id] = ownAlias
            raw = raw.withUpdatedAuthor(ownAlias).withUpdatedFlags(raw.flags.union(.Incoming))
        }
        if raw.id.peerId.namespace == Namespaces.Peer.CloudUser || raw.id.peerId.namespace == Namespaces.Peer.SecretChat {
            let groupId = EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: raw.id.peerId.id)
            peers[groupId] = TelegramGroup(id: groupId, title: "", photo: [], participantCount: 2, role: .member, membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
            raw = raw.withUpdatedId(id: EngineMessage.Id(peerId: groupId, namespace: raw.id.namespace, id: raw.id.id))
        }
        return EngineMessage(raw.withUpdatedPeers(peers))
    }
}

private final class AyuShotRenderPass {
    private static let padding: CGFloat = 12.0
    private static let spacing: CGFloat = 2.0

    private let context: AccountContext
    private let groups: [[EngineMessage]]
    private let options: AyuShotOptions
    private let containerNode: ASDisplayNode
    private let messagesNode: ASDisplayNode
    private var wallpaperNode: WallpaperBackgroundNode?
    private var readyDisposable: Disposable?

    init(context: AccountContext, groups: [[EngineMessage]], options: AyuShotOptions) {
        self.context = context
        self.groups = groups
        self.options = options
        self.containerNode = ASDisplayNode()
        self.containerNode.displaysAsynchronously = false
        self.messagesNode = ASDisplayNode()
        self.messagesNode.displaysAsynchronously = false
        self.messagesNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
    }

    deinit {
        self.readyDisposable?.dispose()
    }

    func render(in parentView: UIView, width: CGFloat, completion: @escaping (UIImage?) -> Void) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let theme = presentationData.theme.withUpdated(preview: true)
        if self.options.showBackground {
            let wallpaperNode = createWallpaperBackgroundNode(context: self.context, forChatDisplay: false)
            wallpaperNode.update(wallpaper: presentationData.chatWallpaper, animated: false)
            wallpaperNode.updateBubbleTheme(bubbleTheme: theme, bubbleCorners: presentationData.chatBubbleCorners)
            self.wallpaperNode = wallpaperNode
            self.containerNode.addSubnode(wallpaperNode)
        }
        self.containerNode.addSubnode(self.messagesNode)
        parentView.addSubview(self.containerNode.view)

        let size = self.layout(presentationData: presentationData, theme: theme, width: width)
        guard size.height > 0.0 else {
            self.containerNode.view.removeFromSuperview()
            completion(nil)
            return
        }
        if let wallpaperNode = self.wallpaperNode {
            wallpaperNode.frame = CGRect(origin: .zero, size: size)
            wallpaperNode.updateLayout(size: size, displayMode: .aspectFill, transition: .immediate)
        }

        let ready: Signal<Bool, NoError>
        if let wallpaperNode = self.wallpaperNode {
            ready = wallpaperNode.isReady
            |> filter { $0 }
            |> take(1)
            |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(true))
        } else {
            ready = .single(true)
        }
        let opaque = self.options.showBackground
        self.readyDisposable = (ready
        |> delay(0.8, queue: Queue.mainQueue())
        |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
            guard let self else {
                return
            }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3.0
            format.opaque = opaque
            let bounds = CGRect(origin: .zero, size: size)
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                self.containerNode.view.drawHierarchy(in: bounds, afterScreenUpdates: true)
            }
            self.containerNode.view.removeFromSuperview()
            completion(image)
        })
    }

    private func layout(presentationData: PresentationData, theme: PresentationTheme, width: CGFloat) -> CGSize {
        let accountPeerId = self.context.account.peerId
        let items: [ListViewItem] = self.groups.map { messages in
            return self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: messages, theme: theme, strings: presentationData.strings, wallpaper: presentationData.chatWallpaper, fontSize: presentationData.chatFontSize, chatBubbleCorners: presentationData.chatBubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.wallpaperNode, availableReactions: nil, accountPeer: nil, isCentered: false, isPreview: true, isStandalone: false, rank: nil, rankRole: nil, isGiftMessageComposerPreview: false, activateGiftMessageInput: nil)
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

        var dateHeaders: [(index: Int, header: ListViewItemHeader)] = []
        if self.options.showDate {
            let calendar = Calendar.current
            for index in 0 ..< self.groups.count {
                guard let message = self.groups[index].first else {
                    continue
                }
                let date = Date(timeIntervalSince1970: TimeInterval(message.timestamp))
                if index > 0, let previous = self.groups[index - 1].first, calendar.isDate(date, inSameDayAs: Date(timeIntervalSince1970: TimeInterval(previous.timestamp))) {
                    continue
                }
                let header = self.context.sharedContext.makeChatMessageDateHeaderItem(context: self.context, timestamp: message.timestamp, theme: theme, strings: presentationData.strings, wallpaper: presentationData.chatWallpaper, fontSize: presentationData.chatFontSize, chatBubbleCorners: presentationData.chatBubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder)
                dateHeaders.append((index, header))
            }
        }

        var frames: [CGRect] = Array(repeating: .zero, count: nodes.count)
        var dateFrames: [Int: CGRect] = [:]
        var offset = AyuShotRenderPass.padding
        for index in (0 ..< nodes.count).reversed() {
            let itemNode = nodes[index]
            let height = itemNode.contentSize.height + itemNode.insets.top + itemNode.insets.bottom
            frames[index] = CGRect(origin: CGPoint(x: 0.0, y: offset), size: CGSize(width: width, height: height))
            offset += height + AyuShotRenderPass.spacing
            if let dateHeader = dateHeaders.first(where: { $0.index == index }) {
                dateFrames[index] = CGRect(origin: CGPoint(x: 0.0, y: offset), size: CGSize(width: width, height: dateHeader.header.height))
                offset += dateHeader.header.height + AyuShotRenderPass.spacing
            }
        }
        let size = CGSize(width: width, height: offset - AyuShotRenderPass.spacing + AyuShotRenderPass.padding)
        for (index, itemNode) in nodes.enumerated() {
            itemNode.frame = frames[index]
            itemNode.updateFrame(itemNode.frame, within: size)
        }

        for dateHeader in dateHeaders {
            guard let frame = dateFrames[dateHeader.index] else {
                continue
            }
            let headerNode = dateHeader.header.node(synchronousLoad: true)
            headerNode.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            self.messagesNode.addSubnode(headerNode)
            headerNode.frame = frame
            headerNode.updateLayout(size: frame.size, leftInset: 0.0, rightInset: 0.0, transition: .immediate)
        }

        for index in 0 ..< self.groups.count {
            guard let message = self.groups[index].first, let author = message.author, message._asMessage().effectivelyIncoming(accountPeerId) else {
                continue
            }
            let nextMessage = index + 1 < self.groups.count ? self.groups[index + 1].first : nil
            if let nextMessage, nextMessage.author?.id == author.id, dateFrames[index + 1] == nil {
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
}
