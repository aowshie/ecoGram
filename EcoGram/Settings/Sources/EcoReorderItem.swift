import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI

final class EcoReorderItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let title: String
    let icon: UIImage?
    let isChecked: Bool
    let sectionId: ItemListSectionId
    let toggle: () -> Void

    init(presentationData: ItemListPresentationData, title: String, icon: UIImage?, isChecked: Bool, sectionId: ItemListSectionId, toggle: @escaping () -> Void) {
        self.presentationData = presentationData
        self.title = title
        self.icon = icon
        self.isChecked = isChecked
        self.sectionId = sectionId
        self.toggle = toggle
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = EcoReorderItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(false) })
                })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? EcoReorderItemNode else {
                return
            }
            let makeLayout = nodeValue.asyncLayout()
            var animated = true
            if case .None = animation {
                animated = false
            }
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply(animated)
                    })
                }
            }
        }
    }

    var selectable: Bool {
        return true
    }

    func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.toggle()
    }
}

private let titleFont = Font.regular(17.0)

final class EcoReorderItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    private let checkNode: ASImageNode
    private let iconNode: ASImageNode
    private let titleNode: TextNode
    private var reorderControlNode: ItemListEditableReorderControlNode?

    private var item: EcoReorderItem?

    var tag: ItemListItemTag? {
        return nil
    }

    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        self.checkNode = ASImageNode()
        self.checkNode.displaysAsynchronously = false
        self.checkNode.isLayerBacked = true
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.isLayerBacked = true
        self.iconNode.contentMode = .center
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false

        super.init(layerBacked: false, rotated: false, seeThrough: false)

        self.addSubnode(self.checkNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
    }

    func asyncLayout() -> (_ item: EcoReorderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let reorderControlLayout = ItemListEditableReorderControlNode.asyncLayout(self.reorderControlNode)
        let currentItem = self.item

        return { [weak self] item, params, neighbors in
            let theme = item.presentationData.theme
            let themeUpdated = currentItem?.presentationData.theme !== theme
            let reorderSizeAndApply = reorderControlLayout(theme)

            let leftInset: CGFloat = 16.0 + params.leftInset
            let checkSize = CGSize(width: 24.0, height: 24.0)
            let iconSize = CGSize(width: 24.0, height: 24.0)
            let titleOffset: CGFloat = leftInset + checkSize.width + 14.0 + (item.icon != nil ? iconSize.width + 12.0 : 0.0)
            let titleColor = item.isChecked ? theme.list.itemPrimaryTextColor : theme.list.itemSecondaryTextColor

            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - titleOffset - params.rightInset - reorderSizeAndApply.0 - 8.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

            let verticalInset: CGFloat = 15.0
            let contentSize = CGSize(width: params.width, height: max(52.0, titleLayout.size.height + verticalInset * 2.0))
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let separatorHeight = UIScreenPixel

            return (layout, { animated in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.item = item
                let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .spring) : .immediate

                if themeUpdated {
                    strongSelf.topStripeNode.backgroundColor = theme.list.itemBlocksSeparatorColor
                    strongSelf.bottomStripeNode.backgroundColor = theme.list.itemBlocksSeparatorColor
                    strongSelf.backgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
                    strongSelf.highlightedBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
                }

                let checkConfiguration = UIImage.SymbolConfiguration(pointSize: 21.0, weight: .regular)
                if item.isChecked {
                    strongSelf.checkNode.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkConfiguration)?.withTintColor(theme.list.itemAccentColor, renderingMode: .alwaysOriginal)
                } else {
                    strongSelf.checkNode.image = UIImage(systemName: "circle", withConfiguration: checkConfiguration)?.withTintColor(theme.list.itemSecondaryTextColor.withAlphaComponent(0.6), renderingMode: .alwaysOriginal)
                }
                strongSelf.iconNode.image = item.icon.flatMap { generateTintedImage(image: $0, color: titleColor) }

                let _ = titleApply()

                if strongSelf.backgroundNode.supernode == nil {
                    strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                }
                if strongSelf.topStripeNode.supernode == nil {
                    strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                }
                if strongSelf.bottomStripeNode.supernode == nil {
                    strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                }
                if strongSelf.maskNode.supernode == nil {
                    strongSelf.addSubnode(strongSelf.maskNode)
                }

                let hasCorners = itemListHasRoundedBlockLayout(params)
                var hasTopCorners = false
                var hasBottomCorners = false
                switch neighbors.top {
                case .sameSection(false):
                    strongSelf.topStripeNode.isHidden = true
                default:
                    hasTopCorners = true
                    strongSelf.topStripeNode.isHidden = hasCorners
                }
                let bottomStripeInset: CGFloat
                let bottomStripeOffset: CGFloat
                switch neighbors.bottom {
                case .sameSection(false):
                    bottomStripeInset = titleOffset
                    bottomStripeOffset = -separatorHeight
                    strongSelf.bottomStripeNode.isHidden = false
                default:
                    bottomStripeInset = 0.0
                    bottomStripeOffset = 0.0
                    hasBottomCorners = true
                    strongSelf.bottomStripeNode.isHidden = hasCorners
                }

                strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(theme, top: hasTopCorners, bottom: hasBottomCorners, glass: true) : nil
                strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.insetBy(dx: params.leftInset, dy: 0.0)
                strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: params.width - bottomStripeInset - params.rightInset - 16.0, height: separatorHeight))
                strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: contentSize.height + UIScreenPixel * 2.0))

                transition.updateFrame(node: strongSelf.checkNode, frame: CGRect(origin: CGPoint(x: leftInset, y: floor((contentSize.height - checkSize.height) / 2.0)), size: checkSize))
                transition.updateFrame(node: strongSelf.iconNode, frame: CGRect(origin: CGPoint(x: leftInset + checkSize.width + 14.0, y: floor((contentSize.height - iconSize.height) / 2.0)), size: iconSize))
                strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: titleOffset, y: floor((contentSize.height - titleLayout.size.height) / 2.0)), size: titleLayout.size)

                let reorderControlNode: ItemListEditableReorderControlNode
                if let current = strongSelf.reorderControlNode {
                    reorderControlNode = current
                    let _ = reorderSizeAndApply.1(contentSize.height, false, transition)
                } else {
                    reorderControlNode = reorderSizeAndApply.1(contentSize.height, false, .immediate)
                    strongSelf.reorderControlNode = reorderControlNode
                    strongSelf.addSubnode(reorderControlNode)
                }
                reorderControlNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - reorderSizeAndApply.0, y: 0.0), size: CGSize(width: reorderSizeAndApply.0, height: contentSize.height))
            })
        }
    }

    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.bottomStripeNode)
            }
        } else if self.highlightedBackgroundNode.supernode != nil {
            if animated {
                self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                    if completed {
                        self?.highlightedBackgroundNode.removeFromSupernode()
                    }
                })
                self.highlightedBackgroundNode.alpha = 0.0
            } else {
                self.highlightedBackgroundNode.removeFromSupernode()
            }
        }
    }

    override func isReorderable(at point: CGPoint) -> Bool {
        if let reorderControlNode = self.reorderControlNode, reorderControlNode.frame.contains(point) {
            return true
        }
        return false
    }

    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }

    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
