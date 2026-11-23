import Foundation
import UIKit
import Photos
import Display
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import GlassBarButtonComponent
import BundleIconComponent
import LottieComponent
import ItemListUI
import PresentationDataUtils
import AttachmentUI
import ContextUI
import UndoUI
import AppBundle
import AccountContext
import EcoStrings

private enum AyuShotSection: Int32 {
    case preview
    case preferences
}

private enum AyuShotOption: String {
    case background
    case date
}

private final class AyuShotArguments {
    let toggle: (AyuShotOption, Bool) -> Void

    init(toggle: @escaping (AyuShotOption, Bool) -> Void) {
        self.toggle = toggle
    }
}

private enum AyuShotEntry: ItemListNodeEntry {
    case preview(image: UIImage?, isLoading: Bool)
    case header(String)
    case option(AyuShotOption, title: String, value: Bool)

    var section: ItemListSectionId {
        switch self {
        case .preview:
            return AyuShotSection.preview.rawValue
        case .header, .option:
            return AyuShotSection.preferences.rawValue
        }
    }

    var stableId: Int {
        switch self {
        case .preview:
            return 0
        case .header:
            return 1
        case let .option(option, _, _):
            return option == .background ? 2 : 3
        }
    }

    static func < (lhs: AyuShotEntry, rhs: AyuShotEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    static func == (lhs: AyuShotEntry, rhs: AyuShotEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.preview(lhsImage, lhsLoading), .preview(rhsImage, rhsLoading)):
            return lhsImage === rhsImage && lhsLoading == rhsLoading
        case let (.header(lhsText), .header(rhsText)):
            return lhsText == rhsText
        case let (.option(lhsOption, lhsTitle, lhsValue), .option(rhsOption, rhsTitle, rhsValue)):
            return lhsOption == rhsOption && lhsTitle == rhsTitle && lhsValue == rhsValue
        default:
            return false
        }
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyuShotArguments
        switch self {
        case let .preview(image, isLoading):
            return AyuShotPreviewItem(presentationData: presentationData, image: image, isLoading: isLoading, sectionId: self.section)
        case let .header(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .option(option, title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(option, value)
            })
        }
    }
}

private struct AyuShotState: Equatable {
    var options: AyuShotOptions
    var image: UIImage?
    var imageOptions: AyuShotOptions?
    var renderingOptions: AyuShotOptions?
    var failed: Bool

    var isLoading: Bool {
        return self.imageOptions != self.options && !self.failed
    }

    static func == (lhs: AyuShotState, rhs: AyuShotState) -> Bool {
        return lhs.options == rhs.options && lhs.image === rhs.image && lhs.imageOptions == rhs.imageOptions && lhs.renderingOptions == rhs.renderingOptions && lhs.failed == rhs.failed
    }
}

final class AyuShotController: ItemListController, AttachmentContainable {
    var requestAttachmentMenuExpansion: () -> Void = {}
    var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    var parentController: () -> ViewController? = {
        return nil
    }
    var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in }
    var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in }
    var cancelPanGesture: () -> Void = {}
    var isContainerPanning: () -> Bool = { return false }
    var isContainerExpanded: () -> Bool = { return false }
    var isMinimized: Bool = false

    var mediaPickerContext: AttachmentMediaPickerContext? {
        return nil
    }
}

private final class AyuShotContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: mainWindowScreenBounds)
    }
}

private func ayuShotController(context: AccountContext, renderer: AyuShotRenderer, renderWidth: CGFloat) -> AyuShotController {
    let initialOptions = AyuShotOptions.stored
    let initialState = AyuShotState(options: initialOptions, image: nil, imageOptions: nil, renderingOptions: nil, failed: false)
    let stateValue = Atomic<AyuShotState>(value: initialState)
    let statePromise = ValuePromise<AyuShotState>(initialState, ignoreRepeated: true)
    let updateState: ((inout AyuShotState) -> Void) -> Void = { f in
        statePromise.set(stateValue.modify { current in
            var current = current
            f(&current)
            return current
        })
    }

    let renderLoop = AyuShotRenderLoop()
    var dismissImpl: (() -> Void)?
    var moreImpl: ((UIView) -> Void)?

    let arguments = AyuShotArguments(toggle: { option, value in
        updateState { state in
            state.failed = false
            switch option {
            case .background:
                state.options.showBackground = value
            case .date:
                state.options.showDate = value
            }
            state.options.store()
        }
        renderLoop.run()
    })

    let barButtonSize = CGSize(width: 44.0, height: 44.0)
    let closeButtonNode = Atomic<BarComponentHostNode?>(value: nil)
    let moreButtonNode = Atomic<BarComponentHostNode?>(value: nil)
    let hostNode: (Atomic<BarComponentHostNode?>, AnyComponentWithIdentity<Empty>) -> BarComponentHostNode = { storage, component in
        return storage.modify { current in
            if let current {
                current.component = component
                return current
            }
            return BarComponentHostNode(component: component, size: barButtonSize)
        }!
    }

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let presentationData = presentationData.withUpdated(theme: presentationData.theme.withModalBlocksBackground())
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let theme = presentationData.theme
        let iconColor = theme.chat.inputPanel.panelControlColor

        let closeButton = GlassBarButtonComponent(
            size: barButtonSize,
            backgroundColor: nil,
            isDark: theme.overallDarkAppearance,
            state: .generic,
            animateScale: false,
            component: AnyComponentWithIdentity(id: "close", component: AnyComponent(BundleIconComponent(name: "Navigation/Close", tintColor: iconColor))),
            action: { _ in
                dismissImpl?()
            },
            accessibility: ComponentAccessibility(label: strings.get(.shotClose))
        )
        let moreButton = GlassBarButtonComponent(
            size: barButtonSize,
            backgroundColor: nil,
            isDark: theme.overallDarkAppearance,
            state: .generic,
            isEnabled: state.image != nil && !state.isLoading,
            animateScale: false,
            component: AnyComponentWithIdentity(id: "more", component: AnyComponent(LottieComponent(content: LottieComponent.AppBundleContent(name: "anim_morewide"), color: iconColor, size: CGSize(width: 34.0, height: 34.0)))),
            action: { view in
                moreImpl?(view)
            },
            accessibility: ComponentAccessibility(label: presentationData.strings.Common_More)
        )
        let leftNavigationButton = ItemListNavigationButton(content: .node(hostNode(closeButtonNode, AnyComponentWithIdentity(id: "close", component: AnyComponent(closeButton)))), style: .regular, enabled: true, action: {})
        let rightNavigationButton = ItemListNavigationButton(content: .node(hostNode(moreButtonNode, AnyComponentWithIdentity(id: "more", component: AnyComponent(moreButton)))), style: .regular, enabled: true, action: {})

        let entries: [AyuShotEntry] = [
            .preview(image: state.image, isLoading: state.isLoading),
            .header(strings.get(.shotPreferences).uppercased()),
            .option(.background, title: strings.get(.shotShowBackground), value: state.options.showBackground),
            .option(.date, title: strings.get(.shotShowDate), value: state.options.showDate)
        ]

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.get(.actionShot)), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = AyuShotController(context: context, state: signal, hideNavigationBarBackground: true)

    let presentToast: (UndoOverlayContent) -> Void = { [weak controller] content in
        guard let controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, position: .top, action: { _ in
            return false
        }), in: .window(.root))
    }
    let presentFailure: () -> Void = {
        let strings = EcoStrings(languageCode: context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode)
        presentToast(.info(title: nil, text: strings.get(.shotFailed), timeout: nil, customUndoText: nil))
    }

    renderLoop.controller = controller
    renderLoop.render = { loop in
        guard let controller = loop.controller else {
            return
        }
        guard controller.view.window != nil else {
            Queue.mainQueue().after(0.1, {
                loop.run()
            })
            return
        }
        let current = stateValue.with { $0 }
        guard current.renderingOptions == nil, current.imageOptions != current.options else {
            return
        }
        let options = current.options
        updateState {
            $0.renderingOptions = options
        }
        renderer.render(in: controller.view, width: renderWidth, options: options, completion: { image in
            let isCurrent = stateValue.with { $0.options } == options
            updateState { state in
                state.renderingOptions = nil
                if isCurrent {
                    if let image {
                        state.image = image
                        state.imageOptions = options
                    } else {
                        state.failed = true
                    }
                }
            }
            if !isCurrent {
                loop.run()
            } else if image == nil {
                presentFailure()
            }
        })
    }

    let copyImage: () -> Void = {
        guard let image = stateValue.with({ $0.image }), let data = image.pngData() else {
            return
        }
        UIPasteboard.general.setData(data, forPasteboardType: "public.png")
        let strings = EcoStrings(languageCode: context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode)
        presentToast(.copy(text: strings.get(.shotCopied)))
    }

    let saveImage: () -> Void = {
        guard let image = stateValue.with({ $0.image }), let data = image.pngData() else {
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    presentFailure()
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }, completionHandler: { success, _ in
                DispatchQueue.main.async {
                    if success {
                        let strings = EcoStrings(languageCode: context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode)
                        presentToast(.mediaSaved(text: strings.get(.shotSaved)))
                    } else {
                        presentFailure()
                    }
                }
            })
        })
    }

    moreImpl = { [weak controller] view in
        guard let controller, stateValue.with({ $0.image }) != nil else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let items: [ContextMenuItem] = [
            .action(ContextMenuActionItem(text: strings.get(.shotCopy), icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                f(.default)
                copyImage()
            })),
            .action(ContextMenuActionItem(text: strings.get(.shotSave), icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Download"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                f(.default)
                saveImage()
            }))
        ]
        let sourceView = controller.navigationBar?.navigationButtonContextContainer(sourceView: view) ?? view
        let contextController = makeContextController(
            presentationData: presentationData,
            source: .reference(AyuShotContextReferenceContentSource(sourceView: sourceView)),
            items: .single(ContextController.Items(content: .list(items))),
            recognizer: nil,
            gesture: nil
        )
        controller.presentInGlobalOverlay(contextController)
    }

    dismissImpl = { [weak controller] in
        controller?.dismiss(animated: true)
    }

    controller.didDisappear = { _ in
        renderer.cancel()
        updateState {
            $0.renderingOptions = nil
        }
    }

    controller.didAppear = { firstTime in
        if firstTime {
            renderLoop.run()
        }
    }

    return controller
}

func ayuShotScreen(context: AccountContext, renderer: AyuShotRenderer, renderWidth: CGFloat) -> ViewController {
    let controller = AttachmentController(context: context, style: .glass, chatLocation: nil, buttons: [.standalone], initialButton: .standalone, fromMenu: false, hasTextInput: false)
    controller.requestController = { _, present in
        let shotController = ayuShotController(context: context, renderer: renderer, renderWidth: renderWidth)
        present(shotController, shotController.mediaPickerContext)
        return true
    }
    controller.navigationPresentation = .flatModal
    return controller
}

private final class AyuShotRenderLoop {
    weak var controller: ViewController?
    var render: ((AyuShotRenderLoop) -> Void)?

    func run() {
        self.render?(self)
    }
}
