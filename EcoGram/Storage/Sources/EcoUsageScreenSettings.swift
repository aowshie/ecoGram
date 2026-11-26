import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import MultilineTextComponent
import ListSectionComponent
import ListActionItemComponent
import ContextUI
import UndoUI
import AppBundle
import TelegramStringFormatting
import StorageUsageScreen
import AyuSettings
import EcoStrings
import EcoAppIcon

extension EcoUsageScreenComponent.View {
    func updateSettings(component: EcoUsageScreenComponent, environment: ViewControllerComponentContainer.Environment, strings: EcoStrings, layout: EcoUsageLayout, contentHeight: CGFloat, transition: ComponentTransition) -> CGFloat {
        var contentHeight = contentHeight
        let settings = AyuSettings.shared

        contentHeight += self.layoutFootnote(self.keepDurationTitleView, text: strings.get(.historyCleanup).uppercased(), isCentered: false, x: nil, y: contentHeight, layout: layout, theme: environment.theme, transition: transition).height
        contentHeight += 8.0

        let keepDurationSize = self.keepDurationItem.update(
            transition: transition,
            component: AnyComponent(StoragePeerTypeItemComponent(
                theme: environment.theme,
                icon: ecoSettingsIcon,
                title: strings.get(.usageKeptItem),
                subtitle: nil,
                value: ecoCleanupTitle(days: settings.historyCleanupDays, strings: environment.strings),
                hasNext: false,
                action: { [weak self] sourceView in
                    self?.openKeepDuration(sourceView: sourceView)
                }
            )),
            environment: {},
            containerSize: CGSize(width: layout.contentWidth, height: 10000.0)
        )
        if let keepDurationView = self.keepDurationItem.view {
            if keepDurationView.superview == nil {
                self.keepDurationSectionContainerView.addSubview(keepDurationView)
            }
            transition.setFrame(view: keepDurationView, frame: CGRect(origin: CGPoint(), size: keepDurationSize))
        }
        self.keepDurationSectionContainerView.backgroundColor = environment.theme.list.itemBlocksBackgroundColor
        transition.setFrame(view: self.keepDurationSectionContainerView, frame: CGRect(origin: CGPoint(x: layout.sideInset, y: contentHeight), size: CGSize(width: layout.contentWidth, height: keepDurationSize.height)))
        contentHeight += keepDurationSize.height
        contentHeight += 8.0
        contentHeight += self.layoutFootnote(self.keepDurationDescriptionView, text: strings.get(.usageCleanupFooter), isCentered: false, x: nil, y: contentHeight, layout: layout, theme: environment.theme, transition: transition).height
        contentHeight += 40.0

        contentHeight += self.layoutFootnote(self.keepSizeTitleView, text: strings.get(.historyMediaLimit).uppercased(), isCentered: false, x: nil, y: contentHeight, layout: layout, theme: environment.theme, transition: transition).height
        contentHeight += 8.0

        let keepSizeSize = self.keepSizeView.update(
            transition: transition,
            component: AnyComponent(EcoKeepSizeComponent(
                theme: environment.theme,
                strings: environment.strings,
                ecoStrings: strings,
                value: settings.historyMediaLimitMegabytes,
                updateValue: { value in
                    AyuSettings.shared.historyMediaLimitMegabytes = value
                }
            )),
            environment: {},
            containerSize: CGSize(width: layout.contentWidth, height: 10000.0)
        )
        if let keepSizeComponentView = self.keepSizeView.view {
            if keepSizeComponentView.superview == nil {
                self.scrollContainerView.addSubview(keepSizeComponentView)
            }
            transition.setFrame(view: keepSizeComponentView, frame: CGRect(origin: CGPoint(x: layout.sideInset, y: contentHeight), size: keepSizeSize))
        }
        contentHeight += keepSizeSize.height
        contentHeight += 8.0
        contentHeight += self.layoutFootnote(self.keepSizeDescriptionView, text: strings.get(.usageMediaFooter), isCentered: false, x: nil, y: contentHeight, layout: layout, theme: environment.theme, transition: transition).height
        contentHeight += 40.0

        let launchSectionSize = self.launchSection.update(
            transition: transition,
            component: AnyComponent(ListSectionComponent(
                theme: environment.theme,
                style: .glass,
                header: nil,
                footer: nil,
                items: [
                    AnyComponentWithIdentity(id: 0, component: AnyComponent(ListActionItemComponent(
                        theme: environment.theme,
                        style: .glass,
                        title: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: strings.get(.usageLaunchClear), font: Font.regular(17.0), textColor: environment.theme.list.itemPrimaryTextColor)),
                            maximumNumberOfLines: 1
                        )),
                        accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: settings.clearHistoryOnLaunch, action: { value in
                            AyuSettings.shared.clearHistoryOnLaunch = value
                        })),
                        action: nil
                    )))
                ]
            )),
            environment: {},
            containerSize: CGSize(width: layout.contentWidth, height: 10000.0)
        )
        if let launchSectionView = self.launchSection.view {
            if launchSectionView.superview == nil {
                self.scrollContainerView.addSubview(launchSectionView)
            }
            transition.setFrame(view: launchSectionView, frame: CGRect(origin: CGPoint(x: layout.sideInset, y: contentHeight), size: launchSectionSize))
        }
        contentHeight += launchSectionSize.height
        contentHeight += 8.0
        contentHeight += self.layoutFootnote(self.launchDescriptionView, text: strings.get(.usageLaunchFooter), isCentered: false, x: nil, y: contentHeight, layout: layout, theme: environment.theme, transition: transition).height
        contentHeight += 40.0

        return contentHeight
    }

    func openKeepDuration(sourceView: StoragePeerTypeItemComponent.View) {
        guard let component = self.component, let labelView = sourceView.labelView else {
            return
        }
        let context = component.context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let currentValue = AyuSettings.shared.historyCleanupDays

        let items: [ContextMenuItem] = AyuSettings.cleanupOptions.map { days -> ContextMenuItem in
            return .action(ContextMenuActionItem(text: ecoCleanupTitle(days: days, strings: presentationData.strings), icon: { theme in
                if currentValue == days {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                } else {
                    return UIImage()
                }
            }, action: { _, f in
                AyuSettings.shared.historyCleanupDays = days
                ecoExpireKept(context: context)
                f(.default)
            }))
        }

        let contextController = makeContextController(
            presentationData: presentationData,
            source: .reference(EcoUsageContextReferenceContentSource(sourceView: labelView)),
            items: .single(ContextController.Items(content: .list(items))),
            gesture: nil
        )
        sourceView.setHasAssociatedMenu(true)
        contextController.dismissed = { [weak sourceView] in
            sourceView?.setHasAssociatedMenu(false)
        }
        self.controller?()?.presentInGlobalOverlay(contextController, with: nil)
    }

    func requestClear() {
        guard let component = self.component, let stats = self.stats else {
            return
        }
        let categories = self.selectedCategories
        guard !categories.isEmpty else {
            return
        }
        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let clearTitle = categories == self.existingCategories ? strings.get(.usageClearAll) : presentationData.strings.StorageManagement_ClearSelected
        self.confirmClear(title: clearTitle, categories: categories, peerIds: component.peer.map { Set([$0.id]) }, clearedSize: stats.clearedSize(categories: categories))
    }

    func requestClearPeers() {
        guard let component = self.component, !self.selectedPeers.isEmpty else {
            return
        }
        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
        self.confirmClear(title: presentationData.strings.StorageManagement_ClearSelected, categories: Set(AyuKeptCategory.allCases), peerIds: self.selectedPeers, clearedSize: self.selectedPeersSize)
    }

    private func confirmClear(title: String, categories: Set<AyuKeptCategory>, peerIds: Set<EnginePeer.Id>?, clearedSize: Int64) {
        guard let component = self.component else {
            return
        }
        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let alertController = textAlertController(
            context: component.context,
            title: strings.get(.usageClearTitle),
            text: strings.get(.usageClearText),
            actions: [
                TextAlertAction(type: .defaultAction, title: title, action: { [weak self] in
                    self?.commitClear(categories: categories, peerIds: peerIds, clearedSize: clearedSize)
                }),
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})
            ],
            actionLayout: .vertical
        )
        self.controller?()?.present(alertController, in: .window(.root))
    }

    private func commitClear(categories: Set<AyuKeptCategory>, peerIds: Set<EnginePeer.Id>?, clearedSize: Int64) {
        guard let component = self.component else {
            return
        }

        self.isClearing = true
        self.state?.updated(transition: .immediate)

        self.clearDisposable.set((component.context.engine.messages.ayuClearKept(categories: categories, peerIds: peerIds)
        |> deliverOnMainQueue).start(next: { [weak self] progress in
            self?.clearingNode?.setProgress(progress)
        }, completed: { [weak self] in
            self?.reloadAfterClear(clearedSize: clearedSize)
        }))
    }

    private func reloadAfterClear(clearedSize: Int64) {
        guard let component = self.component else {
            return
        }
        self.reloadDisposable.set((ecoUsageData(context: component.context, storage: component.context.engine.messages.ayuKeptStorage(), peerId: component.peer?.id)
        |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let self else {
                return
            }
            self.apply(data: data)
            self.deselectedCategories.removeAll()
            self.isSelectingPeers = false
            self.selectedPeers = Set()
            self.isClearing = false
            self.state?.updated(transition: ComponentTransition(animation: .none).withUserData(EcoUsageScreenComponent.AnimationHint(value: .clearedItems)))
            if clearedSize != 0 {
                self.reportClearedStorage(size: clearedSize)
            }
        }))
    }

    private func reportClearedStorage(size: Int64) {
        guard let component = self.component, let controller = self.controller?() else {
            return
        }
        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
        let text = presentationData.strings.ClearCache_Success(dataSizeString(size, formatting: DataSizeStringFormatting(presentationData: presentationData)), stringForDeviceType()).string
        controller.present(UndoOverlayController(presentationData: presentationData, content: .succeed(text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
    }
}

private func ecoCleanupTitle(days: Int, strings: PresentationStrings) -> String {
    if days <= 0 {
        return strings.ClearCache_Never
    }
    return timeIntervalString(strings: strings, value: Int32(days * 24 * 60 * 60))
}
