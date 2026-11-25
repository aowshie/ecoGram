import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import WallpaperBackgroundNode
import EcoStrings

struct AyuShotResult {
    let image: UIImage
    let isTruncated: Bool
}

final class AyuShotRenderer {
    private let context: AccountContext
    private let groups: [[EngineMessage]]
    private let revealsProtectedContent: Bool
    private let mediaReady = Promise<Void>()
    private let prerequisitesDisposable = MetaDisposable()
    private var pass: AyuShotRenderPass?
    private var isRendering = false

    init(context: AccountContext, groups: [[EngineMessage]], revealsProtectedContent: Bool) {
        self.context = context
        self.groups = groups
        self.revealsProtectedContent = revealsProtectedContent
        self.mediaReady.set(ayuShotMediaReady(context: context, messages: groups.flatMap { $0 }))
    }

    deinit {
        self.prerequisitesDisposable.dispose()
    }

    func render(in parentView: UIView, width: CGFloat, options: AyuShotOptions, completion: @escaping (AyuShotResult?) -> Void) {
        guard !self.isRendering else {
            completion(nil)
            return
        }
        self.isRendering = true
        let strings = EcoStrings(languageCode: self.context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode)
        let preparation = AyuShotPreparation(accountPeerId: self.context.account.peerId, revealsProtectedContent: self.revealsProtectedContent, options: options, anonymousTitle: strings.get(.shotAnonymous))
        let groups = preparation.prepare(self.groups)
        self.prerequisitesDisposable.set((combineLatest(self.mediaReady.get() |> take(1), ayuShotAppearance(context: self.context, theme: options.theme), self.context.engine.stickers.availableReactions() |> take(1))
        |> deliverOnMainQueue).startStrict(next: { [weak self, weak parentView] _, appearance, availableReactions in
            guard let self else {
                return
            }
            guard let parentView else {
                self.isRendering = false
                completion(nil)
                return
            }
            let pass = AyuShotRenderPass(context: self.context, groups: groups, options: options, appearance: appearance, availableReactions: availableReactions)
            self.pass = pass
            pass.render(in: parentView, width: width, completion: { [weak self] result in
                self?.pass = nil
                self?.isRendering = false
                completion(result)
            })
        }))
    }

    func cancel() {
        self.prerequisitesDisposable.set(nil)
        self.pass?.cancel()
        self.pass = nil
        self.isRendering = false
    }
}

private final class AyuShotRenderPass {
    private static let padding: CGFloat = 12.0
    private static let maximumPixelHeight: CGFloat = 16384.0

    private let context: AccountContext
    private let groups: [[EngineMessage]]
    private let options: AyuShotOptions
    private let appearance: AyuShotAppearance
    private let availableReactions: AvailableReactions?
    private let containerNode: ASDisplayNode
    private let messagesNode: ASDisplayNode
    private var wallpaperNode: WallpaperBackgroundNode?
    private var readyDisposable: Disposable?

    init(context: AccountContext, groups: [[EngineMessage]], options: AyuShotOptions, appearance: AyuShotAppearance, availableReactions: AvailableReactions?) {
        self.context = context
        self.groups = groups
        self.options = options
        self.appearance = appearance
        self.availableReactions = availableReactions
        self.containerNode = ASDisplayNode()
        self.containerNode.displaysAsynchronously = false
        self.messagesNode = ASDisplayNode()
        self.messagesNode.displaysAsynchronously = false
        self.messagesNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
    }

    deinit {
        self.readyDisposable?.dispose()
    }

    func render(in parentView: UIView, width: CGFloat, completion: @escaping (AyuShotResult?) -> Void) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let theme = self.appearance.theme.withUpdated(preview: true)
        var bubbleCorners = presentationData.chatBubbleCorners
        bubbleCorners.hidesTails = !self.options.showTails
        if self.options.showBackground {
            let wallpaperNode = createWallpaperBackgroundNode(context: self.context, forChatDisplay: false)
            wallpaperNode.update(wallpaper: self.appearance.wallpaper, animated: false)
            wallpaperNode.updateBubbleTheme(bubbleTheme: theme, bubbleCorners: bubbleCorners)
            self.wallpaperNode = wallpaperNode
            self.containerNode.addSubnode(wallpaperNode)
        }
        self.containerNode.addSubnode(self.messagesNode)
        parentView.addSubview(self.containerNode.view)

        let (size, isTruncated) = self.layoutFitting(presentationData: presentationData, theme: theme, bubbleCorners: bubbleCorners, width: width)
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
            format.scale = UIScreen.main.scale
            format.opaque = opaque
            let bounds = CGRect(origin: .zero, size: size)
            var drawn = false
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                drawn = self.containerNode.view.drawHierarchy(in: bounds, afterScreenUpdates: true)
            }
            self.containerNode.view.removeFromSuperview()
            completion(drawn ? AyuShotResult(image: image, isTruncated: isTruncated) : nil)
        })
    }

    func cancel() {
        self.readyDisposable?.dispose()
        self.readyDisposable = nil
        self.containerNode.view.removeFromSuperview()
    }

    private func layoutFitting(presentationData: PresentationData, theme: PresentationTheme, bubbleCorners: PresentationChatBubbleCorners, width: CGFloat) -> (size: CGSize, isTruncated: Bool) {
        var groups = self.groups
        while true {
            let result = self.layout(groups: groups, presentationData: presentationData, theme: theme, bubbleCorners: bubbleCorners, width: width)
            if result.fittingCount >= groups.count {
                return (result.size, groups.count < self.groups.count)
            }
            for subnode in self.messagesNode.subnodes ?? [] {
                subnode.removeFromSupernode()
            }
            groups = Array(groups.prefix(result.fittingCount))
        }
    }

    private static func fittingCount(frames: [CGRect], dateFrames: [Int: CGRect]) -> Int {
        let maximumHeight = AyuShotRenderPass.maximumPixelHeight / UIScreen.main.scale
        var height = AyuShotRenderPass.padding * 2.0
        var count = 0
        for index in 0 ..< frames.count {
            height += frames[index].height + (dateFrames[index]?.height ?? 0.0)
            if height > maximumHeight {
                break
            }
            count = index + 1
        }
        return max(count, 1)
    }

    private func layout(groups: [[EngineMessage]], presentationData: PresentationData, theme: PresentationTheme, bubbleCorners: PresentationChatBubbleCorners, width: CGFloat) -> (size: CGSize, fittingCount: Int) {
        let accountPeerId = self.context.account.peerId
        let items: [ListViewItem] = groups.map { messages in
            return self.context.sharedContext.makeChatMessageSnapshotItem(context: self.context, messages: messages, theme: theme, strings: presentationData.strings, wallpaper: self.appearance.wallpaper, fontSize: presentationData.chatFontSize, chatBubbleCorners: bubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder, backgroundNode: self.wallpaperNode, availableReactions: self.availableReactions)
        }
        let params = ListViewItemLayoutParams(width: width, leftInset: 0.0, rightInset: 0.0, availableHeight: 10000.0)
        var nodes: [ListViewItemNode] = []
        for (index, item) in items.enumerated() {
            let previous = index == items.count - 1 ? nil : items[index + 1].neighborDescriptor
            let next = index == 0 ? nil : items[index - 1].neighborDescriptor
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
        guard nodes.count == groups.count else {
            return (.zero, groups.count)
        }

        var dateHeaders: [(index: Int, header: ListViewItemHeader)] = []
        if self.options.showDate {
            let calendar = Calendar.current
            for index in 0 ..< groups.count {
                guard let message = groups[index].first else {
                    continue
                }
                let date = Date(timeIntervalSince1970: TimeInterval(message.timestamp))
                if index > 0, let previous = groups[index - 1].first, calendar.isDate(date, inSameDayAs: Date(timeIntervalSince1970: TimeInterval(previous.timestamp))) {
                    continue
                }
                let header = self.context.sharedContext.makeChatMessageDateHeaderItem(context: self.context, timestamp: message.timestamp, theme: theme, strings: presentationData.strings, wallpaper: self.appearance.wallpaper, fontSize: presentationData.chatFontSize, chatBubbleCorners: bubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder)
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
            offset += height
            if let dateHeader = dateHeaders.first(where: { $0.index == index }) {
                dateFrames[index] = CGRect(origin: CGPoint(x: 0.0, y: offset), size: CGSize(width: width, height: dateHeader.header.height))
                offset += dateHeader.header.height
            }
        }
        let size = CGSize(width: width, height: offset + AyuShotRenderPass.padding)
        let fittingCount = AyuShotRenderPass.fittingCount(frames: frames, dateFrames: dateFrames)
        if fittingCount < nodes.count {
            return (size, fittingCount)
        }
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

        for index in 0 ..< groups.count {
            guard let message = groups[index].first, let author = message.author, message._asMessage().effectivelyIncoming(accountPeerId) else {
                continue
            }
            let nextMessage = index + 1 < groups.count ? groups[index + 1].first : nil
            if let nextMessage, nextMessage.author?.id == author.id, dateFrames[index + 1] == nil {
                continue
            }
            let header = self.context.sharedContext.makeChatMessageAvatarHeaderItem(context: self.context, timestamp: message.timestamp, peer: author, message: message, theme: theme, strings: presentationData.strings, wallpaper: self.appearance.wallpaper, fontSize: presentationData.chatFontSize, chatBubbleCorners: bubbleCorners, dateTimeFormat: presentationData.dateTimeFormat, nameOrder: presentationData.nameDisplayOrder)
            let headerNode = header.node(synchronousLoad: true)
            headerNode.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            self.messagesNode.addSubnode(headerNode)
            let headerFrame = CGRect(origin: CGPoint(x: 0.0, y: frames[index].minY), size: CGSize(width: width, height: header.height))
            headerNode.frame = headerFrame
            headerNode.updateLayout(size: headerFrame.size, leftInset: 0.0, rightInset: 0.0, transition: .immediate)
        }

        self.containerNode.frame = CGRect(origin: CGPoint(x: -10000.0, y: 0.0), size: size)
        self.messagesNode.frame = CGRect(origin: .zero, size: size)
        return (size, nodes.count)
    }
}
