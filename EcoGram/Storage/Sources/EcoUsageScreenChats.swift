import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import AccountContext
import BottomButtonPanelComponent
import EcoStrings

struct EcoUsageData {
    let storage: AyuKeptStorage
    let total: Int64
    let peers: [EcoUsagePeerItem]
}

func ecoUsageData(context: AccountContext, storage: Signal<AyuKeptStorage, NoError>, peerId: EnginePeer.Id?) -> Signal<EcoUsageData, NoError> {
    return storage
    |> mapToSignal { storage -> Signal<EcoUsageData, NoError> in
        if let peerId {
            return .single(EcoUsageData(storage: storage.peer(peerId), total: storage.total, peers: []))
        }
        let peerIds = Array(storage.peers.keys)
        return context.engine.data.get(EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:))))
        |> map { peers -> EcoUsageData in
            let items = peerIds.compactMap { peerId -> EcoUsagePeerItem? in
                guard let peer = peers[peerId] ?? nil else {
                    return nil
                }
                let size = storage.peers[peerId]?.values.reduce(0, +) ?? 0
                return EcoUsagePeerItem(peer: peer, size: size)
            }
            let sorted = items.sorted { lhs, rhs in
                if lhs.size != rhs.size {
                    return lhs.size > rhs.size
                }
                return lhs.peer.id < rhs.peer.id
            }
            return EcoUsageData(storage: storage, total: storage.total, peers: sorted)
        }
    }
}

extension EcoUsageScreenComponent.View {
    func apply(data: EcoUsageData) {
        self.stats = data.storage
        self.totalSize = data.total
        self.peerItems = data.peers
        let peerIds = Set(data.peers.map(\.peer.id))
        self.selectedPeers = self.selectedPeers.intersection(peerIds)
        if peerIds.isEmpty {
            self.isSelectingPeers = false
        }
    }

    var selectedPeersSize: Int64 {
        return self.stats?.size(peerIds: self.selectedPeers) ?? 0
    }

    func updateNavigationButtons(environment: ViewControllerComponentContainer.Environment, availableSize: CGSize, transition: ComponentTransition) {
        let editButtonSize = self.navigationEditButton.update(
            transition: transition,
            component: AnyComponent(Button(
                content: AnyComponent(Text(text: environment.strings.Common_Edit, font: Font.regular(17.0), color: environment.theme.chat.inputPanel.panelControlColor)),
                contentInsets: UIEdgeInsets(top: 0.0, left: 6.0, bottom: 0.0, right: 6.0),
                action: { [weak self] in
                    guard let self, !self.isSelectingPeers else {
                        return
                    }
                    self.isSelectingPeers = true
                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                }
            ).minSize(CGSize(width: 44.0, height: 44.0))),
            environment: {},
            containerSize: CGSize(width: 150.0, height: 44.0)
        )
        if let editButtonView = self.navigationEditButton.view {
            if editButtonView.superview == nil {
                self.navigationRightButtonsBackground.contentView.addSubview(editButtonView)
            }
            transition.setFrame(view: editButtonView, frame: CGRect(origin: CGPoint(), size: editButtonSize))
            transition.setAlpha(view: editButtonView, alpha: self.isSelectingPeers ? 0.0 : 1.0)
        }

        let doneButtonSize = self.navigationDoneButton.update(
            transition: transition,
            component: AnyComponent(Button(
                content: AnyComponent(Text(text: environment.strings.Common_Done, font: Font.semibold(17.0), color: environment.theme.chat.inputPanel.panelControlColor)),
                contentInsets: UIEdgeInsets(top: 0.0, left: 6.0, bottom: 0.0, right: 6.0),
                action: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.isSelectingPeers = false
                    self.selectedPeers = Set()
                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                }
            ).minSize(CGSize(width: 44.0, height: 44.0))),
            environment: {},
            containerSize: CGSize(width: 150.0, height: 44.0)
        )
        if let doneButtonView = self.navigationDoneButton.view {
            if doneButtonView.superview == nil {
                self.navigationRightButtonsBackground.contentView.addSubview(doneButtonView)
            }
            transition.setFrame(view: doneButtonView, frame: CGRect(origin: CGPoint(), size: doneButtonSize))
            transition.setAlpha(view: doneButtonView, alpha: self.isSelectingPeers ? 1.0 : 0.0)
        }

        let buttonsWidth = self.isSelectingPeers ? doneButtonSize.width : editButtonSize.width
        let backgroundSize = CGSize(width: max(44.0, buttonsWidth), height: 44.0)
        self.navigationRightButtonsBackground.update(size: backgroundSize, cornerRadius: backgroundSize.height * 0.5, isDark: environment.theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
        let backgroundFrame = CGRect(origin: CGPoint(x: availableSize.width - environment.safeInsets.right - environment.navigationBarTrailingButtonsInset - 16.0 - backgroundSize.width, y: environment.statusBarHeight + 2.0 + floor((environment.navigationHeight - environment.statusBarHeight - backgroundSize.height) * 0.5)), size: backgroundSize)
        transition.setFrame(view: self.navigationRightButtonsBackground, frame: backgroundFrame)
    }

    func updateSelectionPanel(component: EcoUsageScreenComponent, environment: ViewControllerComponentContainer.Environment, strings: EcoStrings, availableSize: CGSize, transition: ComponentTransition) -> CGFloat {
        var panelData: (title: String, size: Int64, action: () -> Void)?
        if component.peer != nil {
            if let stats = self.stats, !self.existingCategories.isEmpty {
                let categories = self.selectedCategories
                let title = categories == self.existingCategories ? strings.get(.usageClearAll) : environment.strings.StorageManagement_ClearSelected
                panelData = (title, stats.clearedSize(categories: categories), { [weak self] in
                    self?.requestClear()
                })
            }
        } else if self.isSelectingPeers && !self.selectedPeers.isEmpty {
            panelData = (environment.strings.StorageManagement_ClearSelected, self.selectedPeersSize, { [weak self] in
                self?.requestClearPeers()
            })
        }

        guard let panelData else {
            if let selectionPanel = self.selectionPanel {
                self.selectionPanel = nil
                if let selectionPanelView = selectionPanel.view {
                    transition.setPosition(view: selectionPanelView, position: CGPoint(x: selectionPanelView.center.x, y: availableSize.height + selectionPanelView.bounds.height * 0.5), completion: { [weak selectionPanelView] _ in
                        selectionPanelView?.removeFromSuperview()
                    })
                }
            }
            return environment.safeInsets.bottom
        }

        let selectionPanel: ComponentView<Empty>
        var selectionPanelTransition = transition
        if let current = self.selectionPanel {
            selectionPanel = current
        } else {
            selectionPanelTransition = .immediate
            selectionPanel = ComponentView()
            self.selectionPanel = selectionPanel
        }
        let sideInsets = environment.bottomEdgeSideInsets()
        let selectionPanelSize = selectionPanel.update(
            transition: selectionPanelTransition,
            component: AnyComponent(BottomButtonPanelComponent(
                theme: environment.theme,
                title: panelData.title,
                label: panelData.size == 0 ? nil : dataSizeString(Int(panelData.size), formatting: DataSizeStringFormatting(strings: environment.strings, decimalSeparator: ".")),
                isEnabled: panelData.size != 0,
                insets: UIEdgeInsets(top: 0.0, left: 16.0 + sideInsets.left, bottom: environment.safeInsets.bottom, right: 16.0 + sideInsets.right),
                action: panelData.action
            )),
            environment: {},
            containerSize: availableSize
        )
        if let selectionPanelView = selectionPanel.view {
            var animateIn = false
            if selectionPanelView.superview == nil {
                self.addSubview(selectionPanelView)
                animateIn = true
            }
            selectionPanelTransition.setFrame(view: selectionPanelView, frame: CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - selectionPanelSize.height), size: selectionPanelSize))
            if animateIn {
                transition.animatePosition(view: selectionPanelView, from: CGPoint(x: 0.0, y: selectionPanelSize.height), to: CGPoint(), additive: true)
            }
        }
        return selectionPanelSize.height
    }

    func updateChats(component: EcoUsageScreenComponent, environment: ViewControllerComponentContainer.Environment, strings: EcoStrings, layout: EcoUsageLayout, contentHeight: CGFloat, transition: ComponentTransition) -> CGFloat {
        let visiblePeerIds = Set(self.peerItems.map(\.peer.id))
        for (peerId, itemView) in self.chatItemViews where !visiblePeerIds.contains(peerId) {
            itemView.view?.removeFromSuperview()
            self.chatItemViews.removeValue(forKey: peerId)
        }

        guard !self.peerItems.isEmpty else {
            self.chatsTitleView.view?.removeFromSuperview()
            self.chatsDescriptionView.view?.removeFromSuperview()
            self.chatsSectionContainerView.isHidden = true
            return contentHeight
        }
        self.chatsSectionContainerView.isHidden = false

        var contentHeight = contentHeight
        contentHeight += self.layoutFootnote(self.chatsTitleView, text: environment.strings.StorageManagement_TabChats.uppercased(), isCentered: false, x: nil, y: contentHeight, layout: layout, theme: environment.theme, transition: transition).height
        contentHeight += 8.0

        let formatting = DataSizeStringFormatting(strings: environment.strings, decimalSeparator: ".")
        var itemsHeight: CGFloat = 0.0
        for (index, item) in self.peerItems.enumerated() {
            let itemView: ComponentView<Empty>
            var itemTransition = transition
            if let current = self.chatItemViews[item.peer.id] {
                itemView = current
            } else {
                itemTransition = .immediate
                itemView = ComponentView()
                self.chatItemViews[item.peer.id] = itemView
            }
            let title = item.peer.id == component.context.account.peerId ? environment.strings.DialogList_SavedMessages : item.peer.displayTitle(strings: environment.strings, displayOrder: .firstLast)
            let selectionState: EcoUsagePeerItemComponent.SelectionState = self.isSelectingPeers ? .editing(isSelected: self.selectedPeers.contains(item.peer.id)) : .none
            let itemSize = itemView.update(
                transition: itemTransition,
                component: AnyComponent(EcoUsagePeerItemComponent(
                    context: component.context,
                    theme: environment.theme,
                    title: title,
                    peer: item.peer,
                    label: dataSizeString(Int(item.size), formatting: formatting),
                    selectionState: selectionState,
                    hasNext: index != self.peerItems.count - 1,
                    action: { [weak self] peer in
                        self?.peerPressed(peer)
                    }
                )),
                environment: {},
                containerSize: CGSize(width: layout.contentWidth, height: 100.0)
            )
            if let itemComponentView = itemView.view {
                if itemComponentView.superview == nil {
                    self.chatsSectionContainerView.addSubview(itemComponentView)
                }
                itemTransition.setFrame(view: itemComponentView, frame: CGRect(origin: CGPoint(x: 0.0, y: itemsHeight), size: itemSize))
            }
            itemsHeight += itemSize.height
        }
        self.chatsSectionContainerView.backgroundColor = environment.theme.list.itemBlocksBackgroundColor
        transition.setFrame(view: self.chatsSectionContainerView, frame: CGRect(origin: CGPoint(x: layout.sideInset, y: contentHeight), size: CGSize(width: layout.contentWidth, height: itemsHeight)))
        contentHeight += itemsHeight
        contentHeight += 8.0
        contentHeight += self.layoutFootnote(self.chatsDescriptionView, text: strings.get(.usageChatsFooter), isCentered: false, x: nil, y: contentHeight, layout: layout, theme: environment.theme, transition: transition).height
        contentHeight += 40.0
        return contentHeight
    }

    private func peerPressed(_ peer: EnginePeer) {
        guard let component = self.component else {
            return
        }
        if self.isSelectingPeers {
            if self.selectedPeers.contains(peer.id) {
                self.selectedPeers.remove(peer.id)
            } else {
                self.selectedPeers.insert(peer.id)
            }
            self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
        } else {
            self.controller?()?.push(EcoUsageScreen(context: component.context, peer: peer))
        }
    }
}
