import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import ActivityIndicator

final class AyuShotPreviewItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let image: UIImage?
    let isLoading: Bool
    let sectionId: ItemListSectionId

    let isAlwaysPlain: Bool = true

    init(presentationData: ItemListPresentationData, image: UIImage?, isLoading: Bool, sectionId: ItemListSectionId) {
        self.presentationData = presentationData
        self.image = image
        self.isLoading = isLoading
        self.sectionId = sectionId
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = AyuShotPreviewItemNode()
            let (layout, apply) = node.asyncLayout()(self, params)
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.immediate) })
                })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? AyuShotPreviewItemNode else {
                return
            }
            let makeLayout = nodeValue.asyncLayout()
            async {
                let (layout, apply) = makeLayout(self, params)
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply(animation.isAnimated ? .animated(duration: 0.25, curve: .easeInOut) : .immediate)
                    })
                }
            }
        }
    }
}

final class AyuShotPreviewItemNode: ListViewItemNode {
    private static let placeholderHeight: CGFloat = 220.0
    private static let cornerRadius: CGFloat = 26.0

    private let imageNode: ASImageNode
    private let activityIndicator: ActivityIndicator

    init() {
        self.imageNode = ASImageNode()
        self.imageNode.displaysAsynchronously = false
        self.imageNode.contentMode = .scaleAspectFit
        self.imageNode.clipsToBounds = true
        self.imageNode.cornerRadius = AyuShotPreviewItemNode.cornerRadius

        self.activityIndicator = ActivityIndicator(type: .custom(.gray, 22.0, 2.0, false))

        super.init(layerBacked: false)

        self.addSubnode(self.imageNode)
        self.addSubnode(self.activityIndicator)
    }

    override func didLoad() {
        super.didLoad()
        self.imageNode.layer.cornerCurve = .continuous
    }

    func asyncLayout() -> (_ item: AyuShotPreviewItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (ContainedViewLayoutTransition) -> Void) {
        return { [weak self] item, params in
            let sideInset: CGFloat = 16.0 + params.leftInset
            let imageWidth = params.width - sideInset - 16.0 - params.rightInset
            var imageHeight = AyuShotPreviewItemNode.placeholderHeight
            if let image = item.image, image.size.width > 0.0 {
                imageHeight = ceil(imageWidth * image.size.height / image.size.width)
            }
            let contentSize = CGSize(width: params.width, height: imageHeight)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0))

            return (layout, { transition in
                guard let self else {
                    return
                }
                let theme = item.presentationData.theme
                self.imageNode.image = item.image
                self.imageNode.backgroundColor = item.image == nil ? theme.list.itemBlocksBackgroundColor : nil
                transition.updateFrame(node: self.imageNode, frame: CGRect(x: sideInset, y: 0.0, width: imageWidth, height: imageHeight))
                transition.updateAlpha(node: self.imageNode, alpha: item.isLoading && item.image != nil ? 0.4 : 1.0)

                self.activityIndicator.type = .custom(theme.list.itemSecondaryTextColor, 22.0, 2.0, false)
                self.activityIndicator.isHidden = !item.isLoading
                self.activityIndicator.frame = CGRect(x: floor((params.width - 22.0) / 2.0), y: floor((imageHeight - 22.0) / 2.0), width: 22.0, height: 22.0)
            })
        }
    }

    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }

    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
