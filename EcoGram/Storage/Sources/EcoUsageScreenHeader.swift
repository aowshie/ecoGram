import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import MultilineTextComponent
import AnimatedTextComponent
import Markdown
import RadialStatusNode
import AvatarNode
import AccountContext
import StorageUsageScreen
import EcoStrings

extension EcoUsageScreenComponent.View {
    var selectedCategories: Set<AyuKeptCategory> {
        return self.existingCategories.subtracting(self.deselectedCategories)
    }

    var existingCategories: Set<AyuKeptCategory> {
        guard let stats = self.stats else {
            return Set()
        }
        return Set(AyuKeptCategory.allCases.filter { (stats.sizes[$0] ?? 0) != 0 })
    }

    func updateHeader(component: EcoUsageScreenComponent, environment: ViewControllerComponentContainer.Environment, strings: EcoStrings, layout: EcoUsageLayout, contentHeight: CGFloat, animationHint: EcoUsageScreenComponent.AnimationHint?, transition: ComponentTransition) -> CGFloat {
        var contentHeight = contentHeight
        let selected = self.selectedCategories
        let sizes = self.stats?.sizes ?? [:]

        var totalSelectedSize: Int64 = 0
        for category in AyuKeptCategory.allCases where selected.isEmpty || selected.contains(category) {
            totalSelectedSize += sizes[category] ?? 0
        }

        let presentCategories = AyuKeptCategory.allCases.filter { (sizes[$0] ?? 0) != 0 }.sorted(by: { (sizes[$0] ?? 0) > (sizes[$1] ?? 0) })
        var listCategories: [StorageCategoriesComponent<AyuKeptCategory>.CategoryData] = []
        var chartItems: [PieChartComponent.ChartData.Item] = []
        for category in presentCategories {
            let size = sizes[category] ?? 0
            let fraction: Double
            if !selected.isEmpty && !selected.contains(category) {
                fraction = 0.0
            } else if totalSelectedSize == 0 {
                fraction = 0.0
            } else {
                fraction = Double(size) / Double(totalSelectedSize)
            }
            let title = category.title(strings: strings)
            listCategories.append(StorageCategoriesComponent<AyuKeptCategory>.CategoryData(key: category, color: category.color, title: title, size: size, sizeFraction: fraction, isSelected: selected.contains(category), subcategories: []))
            chartItems.append(PieChartComponent.ChartData.Item(id: category, displayValue: fraction, displaySize: size, value: fraction, color: category.color, particle: category.particle, title: title, mergeable: false, mergeFactor: 1.0))
        }
        self.chartHasData = !listCategories.isEmpty

        var pieChartTransition = transition
        if transition.animation.isImmediate, let animationHint, case .clearedItems = animationHint.value {
            pieChartTransition = ComponentTransition(animation: .curve(duration: 0.4, curve: .spring))
        }
        let pieChartSize = self.pieChartView.update(
            transition: pieChartTransition,
            component: AnyComponent(PieChartComponent(
                theme: environment.theme,
                strings: environment.strings,
                emptyColor: UIColor(rgb: 0x34C759),
                chartData: PieChartComponent.ChartData(items: chartItems)
            )),
            environment: {},
            containerSize: CGSize(width: layout.width, height: 60.0)
        )
        let pieChartFrame = CGRect(origin: CGPoint(x: layout.bandCenterX - layout.width / 2.0, y: contentHeight), size: pieChartSize)
        if let pieChartComponentView = self.pieChartView.view {
            if pieChartComponentView.superview == nil {
                self.headerOffsetContainer.addSubview(pieChartComponentView)
            }
            pieChartTransition.setFrame(view: pieChartComponentView, frame: pieChartFrame)
        }

        if self.stats != nil, listCategories.isEmpty {
            let doneSize = CGSize(width: 100.0, height: 100.0)
            let doneStatusNode: RadialStatusNode
            if let current = self.doneStatusNode {
                doneStatusNode = current
            } else {
                doneStatusNode = RadialStatusNode(backgroundNodeColor: .clear)
                self.doneStatusNode = doneStatusNode
                self.headerOffsetContainer.addSubview(doneStatusNode.view)
                Queue.mainQueue().after(0.18, {
                    doneStatusNode.transitionToState(.check(UIColor(rgb: 0x34C759), lineWidth: 6.0), animated: true)
                })
            }
            doneStatusNode.frame = CGRect(origin: CGPoint(x: floor(layout.bandCenterX - doneSize.width / 2.0), y: contentHeight + (92.0 - doneSize.height) * 0.5), size: doneSize)
            contentHeight += doneSize.height
        } else {
            contentHeight += pieChartSize.height
            if let doneStatusNode = self.doneStatusNode {
                self.doneStatusNode = nil
                doneStatusNode.removeFromSupernode()
            }
        }

        contentHeight += 23.0

        let headerText: String
        if listCategories.isEmpty {
            headerText = environment.strings.StorageManagement_TitleCleared
        } else if let peer = component.peer {
            headerText = peer.id == component.context.account.peerId ? environment.strings.DialogList_SavedMessages : peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)
        } else {
            headerText = strings.get(.usageTitle)
        }
        let headerViewSize = self.headerView.update(
            transition: transition,
            component: AnyComponent(Text(text: headerText, font: Font.semibold(20.0), color: environment.theme.list.itemPrimaryTextColor)),
            environment: {},
            containerSize: CGSize(width: floor((layout.width - 88.0) / 0.8), height: 100.0)
        )
        let headerViewFrame = CGRect(origin: CGPoint(x: floor(layout.bandCenterX - headerViewSize.width / 2.0), y: contentHeight), size: headerViewSize)
        if let headerComponentView = self.headerView.view {
            if headerComponentView.superview == nil {
                headerComponentView.accessibilityTraits = .header
                self.headerOffsetContainer.addSubview(headerComponentView)
            }
            transition.setPosition(view: headerComponentView, position: headerViewFrame.center)
            transition.setBounds(view: headerComponentView, bounds: CGRect(origin: CGPoint(), size: headerViewFrame.size))
        }
        contentHeight += headerViewSize.height
        contentHeight += 6.0

        let usageFraction = component.peer == nil ? self.usageFraction() : self.chatFraction()
        let descriptionText: String
        if listCategories.isEmpty {
            descriptionText = strings.get(.usageEmpty)
        } else if component.peer != nil {
            descriptionText = strings.format(.usageChatDescription, ecoFractionString(usageFraction))
        } else {
            descriptionText = strings.format(.usageDescription, ecoFractionString(usageFraction))
        }
        let headerDescriptionSize = self.layoutFootnote(self.headerDescriptionView, text: descriptionText, isCentered: true, x: nil, y: contentHeight, layout: layout, theme: environment.theme, transition: transition)
        contentHeight += headerDescriptionSize.height
        contentHeight += 8.0

        let headerProgressWidth: CGFloat = min(200.0, layout.contentWidth)
        let headerProgressFrame = CGRect(origin: CGPoint(x: floor(layout.bandCenterX - headerProgressWidth / 2.0), y: contentHeight), size: CGSize(width: headerProgressWidth, height: 4.0))
        transition.setFrame(layer: self.headerProgressBackgroundLayer, frame: headerProgressFrame)
        transition.setCornerRadius(layer: self.headerProgressBackgroundLayer, cornerRadius: headerProgressFrame.height * 0.5)
        self.headerProgressBackgroundLayer.backgroundColor = environment.theme.list.itemAccentColor.withMultipliedAlpha(0.2).cgColor
        transition.setFrame(layer: self.headerProgressForegroundLayer, frame: CGRect(origin: headerProgressFrame.origin, size: CGSize(width: max(headerProgressFrame.height, floorToScreenPixels(CGFloat(usageFraction) * headerProgressFrame.width)), height: headerProgressFrame.height)))
        transition.setCornerRadius(layer: self.headerProgressForegroundLayer, cornerRadius: headerProgressFrame.height * 0.5)
        self.headerProgressForegroundLayer.backgroundColor = environment.theme.list.itemAccentColor.cgColor
        transition.setAlpha(layer: self.headerProgressBackgroundLayer, alpha: listCategories.isEmpty ? 0.0 : 1.0)
        transition.setAlpha(layer: self.headerProgressForegroundLayer, alpha: listCategories.isEmpty ? 0.0 : 1.0)
        contentHeight += 4.0
        contentHeight += 24.0

        if let peer = component.peer {
            self.chartTotalLabel.view?.removeFromSuperview()
            self.updateChartAvatar(component: component, peer: peer, isVisible: !listCategories.isEmpty, pieChartFrame: pieChartFrame, environment: environment, transition: transition)
        } else {
            self.updateChartTotal(size: totalSelectedSize, pieChartFrame: pieChartFrame, environment: environment, transition: transition)
        }

        if !listCategories.isEmpty {
            let categoriesSize = self.categoriesView.update(
                transition: transition,
                component: AnyComponent(StorageCategoriesComponent<AyuKeptCategory>(
                    theme: environment.theme,
                    strings: environment.strings,
                    categories: listCategories,
                    isOtherExpanded: false,
                    displayAction: component.peer == nil,
                    clearAllTitle: strings.get(.usageClearAll),
                    toggleCategorySelection: { [weak self] category in
                        guard let self else {
                            return
                        }
                        if self.deselectedCategories.contains(category) {
                            self.deselectedCategories.remove(category)
                        } else {
                            self.deselectedCategories.insert(category)
                        }
                        self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                    },
                    toggleOtherExpanded: {},
                    clearAction: { [weak self] in
                        self?.requestClear()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: layout.contentWidth, height: .greatestFiniteMagnitude)
            )
            if let categoriesComponentView = self.categoriesView.view {
                if categoriesComponentView.superview == nil {
                    self.scrollContainerView.addSubview(categoriesComponentView)
                }
                transition.setFrame(view: categoriesComponentView, frame: CGRect(origin: CGPoint(x: layout.sideInset, y: contentHeight), size: categoriesSize))
            }
            contentHeight += categoriesSize.height
            contentHeight += 8.0
            contentHeight += self.layoutFootnote(self.categoriesDescriptionView, text: strings.get(.usageCategoriesFooter), isCentered: false, x: nil, y: contentHeight, layout: layout, theme: environment.theme, transition: transition).height
            contentHeight += 40.0
        } else {
            self.categoriesView.view?.removeFromSuperview()
            self.categoriesDescriptionView.view?.removeFromSuperview()
        }

        return contentHeight
    }

    private func updateChartTotal(size: Int64, pieChartFrame: CGRect, environment: ViewControllerComponentContainer.Environment, transition: ComponentTransition) {
        var remainingSizeText = dataSizeString(Int(size), forceDecimal: true, formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: "."))
        var animatedTextItems: [AnimatedTextComponent.Item] = []
        if let index = remainingSizeText.firstIndex(of: ".") {
            animatedTextItems.append(AnimatedTextComponent.Item(id: "n-full", content: .text(String(remainingSizeText[remainingSizeText.startIndex ..< index]))))
            animatedTextItems.append(AnimatedTextComponent.Item(id: "dot", content: .text(".")))
            remainingSizeText = String(remainingSizeText[remainingSizeText.index(after: index)...])
        }
        if let index = remainingSizeText.firstIndex(of: " ") {
            animatedTextItems.append(AnimatedTextComponent.Item(id: "n-fract", content: .text(String(remainingSizeText[remainingSizeText.startIndex ..< index]))))
            remainingSizeText = String(remainingSizeText[index...])
        }
        if !remainingSizeText.isEmpty {
            animatedTextItems.append(AnimatedTextComponent.Item(id: "rest", isUnbreakable: true, content: .text(remainingSizeText)))
        }

        let chartTotalLabelSize = self.chartTotalLabel.update(
            transition: transition,
            component: AnyComponent(AnimatedTextComponent(
                font: Font.with(size: 20.0, design: .round, weight: .bold),
                color: environment.theme.list.itemPrimaryTextColor,
                items: animatedTextItems
            )),
            environment: {},
            containerSize: CGSize(width: 200.0, height: 200.0)
        )
        if let chartTotalLabelView = self.chartTotalLabel.view {
            if chartTotalLabelView.superview == nil {
                self.headerOffsetContainer.addSubview(chartTotalLabelView)
            }
            transition.setFrame(view: chartTotalLabelView, frame: CGRect(origin: CGPoint(x: pieChartFrame.minX + floor((pieChartFrame.width - chartTotalLabelSize.width) / 2.0), y: pieChartFrame.minY + floor((pieChartFrame.height - chartTotalLabelSize.height) / 2.0)), size: chartTotalLabelSize))
        }
    }

    private func updateChartAvatar(component: EcoUsageScreenComponent, peer: EnginePeer, isVisible: Bool, pieChartFrame: CGRect, environment: ViewControllerComponentContainer.Environment, transition: ComponentTransition) {
        let avatarSize = CGSize(width: 72.0, height: 72.0)
        let avatarFrame = CGRect(origin: CGPoint(x: pieChartFrame.minX + floor((pieChartFrame.width - avatarSize.width) / 2.0), y: pieChartFrame.minY + floor((pieChartFrame.height - avatarSize.height) / 2.0)), size: avatarSize)
        let chartAvatarNode: AvatarNode
        if let current = self.chartAvatarNode {
            chartAvatarNode = current
            transition.setFrame(view: chartAvatarNode.view, frame: avatarFrame)
        } else {
            chartAvatarNode = AvatarNode(font: avatarPlaceholderFont(size: 17.0))
            self.chartAvatarNode = chartAvatarNode
            self.headerOffsetContainer.addSubview(chartAvatarNode.view)
            chartAvatarNode.frame = avatarFrame
            if peer.id == component.context.account.peerId {
                chartAvatarNode.setPeer(context: component.context, theme: environment.theme, peer: peer, overrideImage: .savedMessagesIcon, displayDimensions: avatarSize)
            } else {
                chartAvatarNode.setPeer(context: component.context, theme: environment.theme, peer: peer, displayDimensions: avatarSize)
            }
        }
        chartAvatarNode.view.isHidden = !isVisible
    }

    private func chatFraction() -> Double {
        let size = self.stats?.total ?? 0
        guard size != 0, self.totalSize != 0 else {
            return 0.0
        }
        return min(1.0, Double(size) / Double(self.totalSize))
    }

    private func usageFraction() -> Double {
        let total = self.stats?.total ?? 0
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        let freeSpace = (attributes?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        guard total != 0, freeSpace != 0 else {
            return 0.0
        }
        return Double(total) / Double(freeSpace + total)
    }

    func layoutFootnote(_ view: ComponentView<Empty>, text: String, isCentered: Bool, x: CGFloat?, y: CGFloat, layout: EcoUsageLayout, theme: PresentationTheme, transition: ComponentTransition) -> CGSize {
        let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.freeTextColor)
        let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: theme.list.freeTextColor)
        let size = view.update(
            transition: transition,
            component: AnyComponent(MultilineTextComponent(
                text: .markdown(text: text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil })),
                horizontalAlignment: isCentered ? .center : .natural,
                maximumNumberOfLines: 0
            )),
            environment: {},
            containerSize: CGSize(width: layout.textWidth, height: 10000.0)
        )
        let originX = isCentered ? floor(layout.bandCenterX - size.width / 2.0) : (x ?? layout.sideInset + 15.0)
        if let componentView = view.view {
            if componentView.superview == nil {
                self.scrollContainerView.addSubview(componentView)
            }
            transition.setFrame(view: componentView, frame: CGRect(origin: CGPoint(x: originX, y: y), size: size))
        }
        return size
    }
}

private func ecoFractionString(_ fraction: Double) -> String {
    let value = floor(fraction * 100.0 * 10.0) / 10.0
    if value < 0.1 {
        return "<0.1"
    } else if abs(Double(Int(value)) - value) < 0.001 {
        return "\(Int(value))"
    } else {
        return "\(value)"
    }
}
