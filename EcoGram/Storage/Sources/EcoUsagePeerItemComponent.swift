import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AccountContext
import MultilineTextComponent
import AvatarNode
import CheckNode

private let avatarFont = avatarPlaceholderFont(size: 15.0)

final class EcoUsagePeerItemComponent: Component {
    enum SelectionState: Equatable {
        case none
        case editing(isSelected: Bool)
    }

    let context: AccountContext
    let theme: PresentationTheme
    let title: String
    let peer: EnginePeer
    let label: String
    let selectionState: SelectionState
    let hasNext: Bool
    let action: (EnginePeer) -> Void

    init(context: AccountContext, theme: PresentationTheme, title: String, peer: EnginePeer, label: String, selectionState: SelectionState, hasNext: Bool, action: @escaping (EnginePeer) -> Void) {
        self.context = context
        self.theme = theme
        self.title = title
        self.peer = peer
        self.label = label
        self.selectionState = selectionState
        self.hasNext = hasNext
        self.action = action
    }

    static func ==(lhs: EcoUsagePeerItemComponent, rhs: EcoUsagePeerItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.label != rhs.label {
            return false
        }
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        if lhs.hasNext != rhs.hasNext {
            return false
        }
        return true
    }

    final class View: UIView {
        private let containerButton: HighlightTrackingButton
        private let title = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        private let separatorLayer: SimpleLayer
        private let avatarNode: AvatarNode
        private var checkLayer: CheckLayer?
        private var highlightBackgroundLayer: SimpleLayer?

        private var component: EcoUsagePeerItemComponent?

        override init(frame: CGRect) {
            self.separatorLayer = SimpleLayer()
            self.containerButton = HighlightTrackingButton()
            self.avatarNode = AvatarNode(font: avatarFont)
            self.avatarNode.isLayerBacked = true

            super.init(frame: frame)

            self.layer.addSublayer(self.separatorLayer)
            self.addSubview(self.containerButton)
            self.containerButton.layer.addSublayer(self.avatarNode.layer)

            self.containerButton.highligthedChanged = { [weak self] isHighlighted in
                self?.updateHighlight(isHighlighted: isHighlighted)
            }
            self.containerButton.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action(component.peer)
        }

        private func updateHighlight(isHighlighted: Bool) {
            guard let component = self.component else {
                return
            }
            if isHighlighted, case .none = component.selectionState {
                let highlightBackgroundLayer: SimpleLayer
                if let current = self.highlightBackgroundLayer {
                    highlightBackgroundLayer = current
                } else {
                    highlightBackgroundLayer = SimpleLayer()
                    self.highlightBackgroundLayer = highlightBackgroundLayer
                    self.layer.insertSublayer(highlightBackgroundLayer, above: self.separatorLayer)
                }
                highlightBackgroundLayer.backgroundColor = component.theme.list.itemHighlightedBackgroundColor.cgColor
                highlightBackgroundLayer.frame = self.bounds
                highlightBackgroundLayer.opacity = 1.0
            } else if let highlightBackgroundLayer = self.highlightBackgroundLayer {
                self.highlightBackgroundLayer = nil
                highlightBackgroundLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak highlightBackgroundLayer] _ in
                    highlightBackgroundLayer?.removeFromSuperlayer()
                })
            }
        }

        func update(component: EcoUsagePeerItemComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            self.component = component

            self.containerButton.isAccessibilityElement = true
            self.containerButton.accessibilityLabel = component.title
            self.containerButton.accessibilityValue = component.label
            if case .editing(true) = component.selectionState {
                self.containerButton.accessibilityTraits = [.button, .selected]
            } else {
                self.containerButton.accessibilityTraits = .button
            }

            let height: CGFloat = 52.0
            var leftInset: CGFloat = 62.0
            var avatarLeftInset: CGFloat = 10.0

            if case let .editing(isSelected) = component.selectionState {
                leftInset += 48.0
                avatarLeftInset += 48.0

                let checkSize: CGFloat = 22.0
                let checkLayer: CheckLayer
                if let current = self.checkLayer {
                    checkLayer = current
                    if themeUpdated {
                        checkLayer.theme = CheckNodeTheme(theme: component.theme, style: .plain)
                    }
                    checkLayer.setSelected(isSelected, animated: !transition.animation.isImmediate)
                } else {
                    checkLayer = CheckLayer(theme: CheckNodeTheme(theme: component.theme, style: .plain))
                    self.checkLayer = checkLayer
                    self.containerButton.layer.addSublayer(checkLayer)
                    checkLayer.frame = CGRect(origin: CGPoint(x: -checkSize, y: floor((height - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize))
                    checkLayer.setSelected(isSelected, animated: false)
                    checkLayer.setNeedsDisplay()
                }
                transition.setFrame(layer: checkLayer, frame: CGRect(origin: CGPoint(x: 20.0, y: floor((height - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize)))
            } else if let checkLayer = self.checkLayer {
                self.checkLayer = nil
                transition.setPosition(layer: checkLayer, position: CGPoint(x: -checkLayer.bounds.width * 0.5, y: checkLayer.position.y), completion: { [weak checkLayer] _ in
                    checkLayer?.removeFromSuperlayer()
                })
            }

            let rightInset: CGFloat = 16.0
            let avatarSize: CGFloat = 40.0
            let avatarFrame = CGRect(origin: CGPoint(x: avatarLeftInset, y: floor((height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
            if self.avatarNode.bounds.isEmpty {
                self.avatarNode.frame = avatarFrame
            } else {
                transition.setFrame(layer: self.avatarNode.layer, frame: avatarFrame)
            }
            let clipStyle: AvatarNodeClipStyle
            if case let .channel(channel) = component.peer, channel.isForumOrMonoForum {
                clipStyle = .roundedRect
            } else {
                clipStyle = .round
            }
            if component.peer.id == component.context.account.peerId {
                self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.peer, overrideImage: .savedMessagesIcon, clipStyle: clipStyle, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
            } else {
                self.avatarNode.setPeer(context: component.context, theme: component.theme, peer: component.peer, clipStyle: clipStyle, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
            }

            let labelSize = self.label.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.label, font: Font.regular(17.0), textColor: component.theme.list.itemSecondaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset, height: 100.0)
            )
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.semibold(17.0), textColor: component.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftInset - rightInset - labelSize.width - 4.0, height: 100.0)
            )

            let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                let previousTitleFrame = titleView.superview == nil ? nil : titleView.frame
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(titleView)
                }
                titleView.frame = titleFrame
                if let previousTitleFrame, previousTitleFrame.minX != titleFrame.minX {
                    transition.animatePosition(view: titleView, from: CGPoint(x: previousTitleFrame.minX - titleFrame.minX, y: 0.0), to: CGPoint(), additive: true)
                }
            }
            if let labelView = self.label.view {
                if labelView.superview == nil {
                    labelView.isUserInteractionEnabled = false
                    self.containerButton.addSubview(labelView)
                }
                transition.setFrame(view: labelView, frame: CGRect(origin: CGPoint(x: availableSize.width - rightInset - labelSize.width, y: floor((height - labelSize.height) / 2.0)), size: labelSize))
            }

            if themeUpdated {
                self.separatorLayer.backgroundColor = component.theme.list.itemBlocksSeparatorColor.cgColor
            }
            transition.setFrame(layer: self.separatorLayer, frame: CGRect(origin: CGPoint(x: leftInset, y: height - UIScreenPixel), size: CGSize(width: availableSize.width - leftInset, height: UIScreenPixel)))
            self.separatorLayer.isHidden = !component.hasNext

            transition.setFrame(view: self.containerButton, frame: CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: height)))

            return CGSize(width: availableSize.width, height: height)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
