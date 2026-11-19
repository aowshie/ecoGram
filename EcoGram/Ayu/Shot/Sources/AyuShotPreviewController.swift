import Foundation
import UIKit
import Photos
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ComponentFlow
import GlassBarButtonComponent
import BundleIconComponent
import LottieComponent
import ContextUI
import UndoUI
import AppBundle
import AccountContext
import EcoStrings

final class AyuShotPreviewController: ViewController {
    private static let backgroundKey = "ecogram.shot.showBackground"
    private static let dateKey = "ecogram.shot.showDate"
    private static let rowHeight: CGFloat = 52.0
    private static let headerHeight: CGFloat = 68.0
    private static let buttonSize: CGFloat = 44.0

    private let renderer: AyuShotRenderer
    private let renderWidth: CGFloat
    private let presentationData: PresentationData
    private let strings: EcoStrings

    private var options: AyuShotOptions
    private var images: [AyuShotOptions: UIImage] = [:]
    private var isRendering = false
    private var image: UIImage?
    private var validLayout: ContainerViewLayout?
    private var didAppear = false
    private var isDismissing = false

    private let dimView = UIView()
    private let sheetClipView = UIView()
    private let sheetView = UIView()
    private let titleLabel = UILabel()
    private let closeButton = ComponentView<Empty>()
    private let moreButton = ComponentView<Empty>()
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let activityView = UIActivityIndicatorView(style: .medium)
    private let preferencesLabel = UILabel()
    private let preferencesCard = UIView()
    private let separatorView = UIView()
    private let backgroundSwitch = UISwitch()
    private let dateSwitch = UISwitch()
    private var rows: [AyuShotPreferenceRow] = []

    private var theme: PresentationTheme {
        return self.presentationData.theme
    }

    init(context: AccountContext, renderer: AyuShotRenderer, renderWidth: CGFloat) {
        self.renderer = renderer
        self.renderWidth = renderWidth
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.strings = EcoStrings(languageCode: self.presentationData.strings.baseLanguageCode)
        let defaults = UserDefaults.standard
        self.options = AyuShotOptions(
            showBackground: defaults.object(forKey: AyuShotPreviewController.backgroundKey) as? Bool ?? true,
            showDate: defaults.object(forKey: AyuShotPreviewController.dateKey) as? Bool ?? false
        )
        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = .Ignore
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        let view = self.displayNode.view
        let list = self.theme.list

        self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        self.dimView.alpha = 0.0
        self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.closePressed)))
        view.addSubview(self.dimView)

        self.sheetClipView.layer.cornerCurve = .continuous
        self.sheetClipView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        self.sheetClipView.clipsToBounds = true
        view.addSubview(self.sheetClipView)

        self.sheetView.backgroundColor = list.blocksBackgroundColor
        self.sheetView.layer.cornerRadius = 38.0
        self.sheetView.layer.cornerCurve = .continuous
        self.sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        self.sheetView.clipsToBounds = true
        self.sheetClipView.addSubview(self.sheetView)

        self.titleLabel.text = self.strings.get(.actionShot)
        self.titleLabel.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        self.titleLabel.textColor = list.itemPrimaryTextColor
        self.titleLabel.textAlignment = .center
        self.sheetView.addSubview(self.titleLabel)

        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.alwaysBounceVertical = true
        self.sheetView.addSubview(self.scrollView)

        self.imageView.contentMode = .scaleAspectFit
        self.imageView.layer.cornerRadius = 26.0
        self.imageView.layer.cornerCurve = .continuous
        self.imageView.clipsToBounds = true
        self.scrollView.addSubview(self.imageView)

        self.activityView.color = list.itemSecondaryTextColor
        self.activityView.hidesWhenStopped = true
        self.sheetView.addSubview(self.activityView)

        self.preferencesLabel.text = self.strings.get(.shotPreferences).uppercased()
        self.preferencesLabel.font = UIFont.systemFont(ofSize: 13.0)
        self.preferencesLabel.textColor = list.sectionHeaderTextColor
        self.sheetView.addSubview(self.preferencesLabel)

        self.preferencesCard.backgroundColor = list.itemBlocksBackgroundColor
        self.preferencesCard.layer.cornerRadius = 26.0
        self.preferencesCard.layer.cornerCurve = .continuous
        self.preferencesCard.clipsToBounds = true
        self.sheetView.addSubview(self.preferencesCard)

        self.addRow(title: self.strings.get(.shotShowBackground), toggle: self.backgroundSwitch, isOn: self.options.showBackground)
        self.addRow(title: self.strings.get(.shotShowDate), toggle: self.dateSwitch, isOn: self.options.showDate)
        self.separatorView.backgroundColor = list.itemBlocksSeparatorColor
        self.preferencesCard.addSubview(self.separatorView)

        self.updateHeaderButtons()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.validLayout = layout
        self.layoutSheet()
    }

    private func layoutSheet() {
        guard let layout = self.validLayout, self.isNodeLoaded else {
            return
        }
        let size = layout.size
        let topInset = layout.statusBarHeight ?? layout.safeInsets.top
        self.dimView.frame = CGRect(origin: .zero, size: size)

        let glassInset: CGFloat = size.width < size.height ? 6.0 : 0.0
        let sheetWidth = size.width - glassInset * 2.0
        let side: CGFloat = 16.0
        let rowHeight = AyuShotPreviewController.rowHeight
        let headerHeight = AyuShotPreviewController.headerHeight
        let cardHeight = rowHeight * 2.0
        let preferencesHeight: CGFloat = 32.0 + cardHeight
        let bottomInset = max(layout.intrinsicInsets.bottom - glassInset, 16.0)
        let maxSheetHeight = size.height - topInset - 12.0
        let imageWidth = sheetWidth - side * 2.0
        var imageHeight: CGFloat = 220.0
        if let image = self.image, image.size.width > 0.0 {
            imageHeight = ceil(imageWidth * image.size.height / image.size.width)
        }
        let fixedHeight = headerHeight + 8.0 + preferencesHeight + 16.0 + bottomInset
        let scrollHeight = min(imageHeight, max(120.0, maxSheetHeight - fixedHeight))
        let sheetHeight = fixedHeight + scrollHeight
        let sheetOrigin = self.didAppear && !self.isDismissing ? size.height - glassInset - sheetHeight : size.height
        self.sheetClipView.layer.cornerRadius = max(24.0, layout.deviceMetrics.screenCornerRadius) - 2.0
        self.sheetClipView.frame = CGRect(x: glassInset, y: sheetOrigin, width: sheetWidth, height: sheetHeight)
        self.sheetView.frame = self.sheetClipView.bounds

        let buttonSize = AyuShotPreviewController.buttonSize
        let buttonY = floor((headerHeight - buttonSize) / 2.0)
        self.closeButton.view?.frame = CGRect(x: side, y: buttonY, width: buttonSize, height: buttonSize)
        self.moreButton.view?.frame = CGRect(x: sheetWidth - side - buttonSize, y: buttonY, width: buttonSize, height: buttonSize)
        self.titleLabel.frame = CGRect(x: side + buttonSize + 8.0, y: 0.0, width: sheetWidth - (side + buttonSize + 8.0) * 2.0, height: headerHeight)

        self.scrollView.frame = CGRect(x: 0.0, y: headerHeight, width: sheetWidth, height: scrollHeight)
        self.imageView.frame = CGRect(x: side, y: 0.0, width: imageWidth, height: imageHeight)
        self.scrollView.contentSize = CGSize(width: sheetWidth, height: imageHeight)
        self.activityView.center = CGPoint(x: self.scrollView.frame.midX, y: self.scrollView.frame.midY)

        let preferencesTop = self.scrollView.frame.maxY + 8.0
        self.preferencesLabel.frame = CGRect(x: side * 2.0, y: preferencesTop + 8.0, width: sheetWidth - side * 4.0, height: 18.0)
        self.preferencesCard.frame = CGRect(x: side, y: preferencesTop + 32.0, width: sheetWidth - side * 2.0, height: cardHeight)
        let cardWidth = self.preferencesCard.bounds.width
        for (index, row) in self.rows.enumerated() {
            row.frame = CGRect(x: 0.0, y: CGFloat(index) * rowHeight, width: cardWidth, height: rowHeight)
        }
        self.separatorView.frame = CGRect(x: side, y: rowHeight - UIScreenPixel, width: cardWidth - side, height: UIScreenPixel)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !self.didAppear else {
            return
        }
        self.didAppear = true
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.dimView.alpha = 1.0
            self.layoutSheet()
        })
        self.renderCurrent()
    }

    private func updateHeaderButtons() {
        guard self.isNodeLoaded else {
            return
        }
        let size = CGSize(width: AyuShotPreviewController.buttonSize, height: AyuShotPreviewController.buttonSize)
        let isDark = self.theme.overallDarkAppearance
        let iconColor = self.theme.chat.inputPanel.panelControlColor
        let _ = self.closeButton.update(
            transition: .immediate,
            component: AnyComponent(GlassBarButtonComponent(
                size: size,
                backgroundColor: nil,
                isDark: isDark,
                state: .glass,
                component: AnyComponentWithIdentity(id: "close", component: AnyComponent(BundleIconComponent(name: "Navigation/Close", tintColor: iconColor))),
                action: { [weak self] _ in
                    self?.closePressed()
                },
                accessibility: ComponentAccessibility(label: self.strings.get(.shotClose))
            )),
            environment: {},
            containerSize: size
        )
        let _ = self.moreButton.update(
            transition: .immediate,
            component: AnyComponent(GlassBarButtonComponent(
                size: size,
                backgroundColor: nil,
                isDark: isDark,
                state: .glass,
                isEnabled: self.image != nil && !self.isRendering,
                component: AnyComponentWithIdentity(id: "more", component: AnyComponent(LottieComponent(content: LottieComponent.AppBundleContent(name: "anim_morewide"), color: iconColor, size: CGSize(width: 34.0, height: 34.0)))),
                action: { [weak self] view in
                    self?.morePressed(view: view)
                }
            )),
            environment: {},
            containerSize: size
        )
        if let view = self.closeButton.view, view.superview == nil {
            self.sheetView.addSubview(view)
        }
        if let view = self.moreButton.view, view.superview == nil {
            self.sheetView.addSubview(view)
        }
    }

    private func morePressed(view: UIView) {
        guard self.image != nil else {
            return
        }
        let items: [ContextMenuItem] = [
            .action(ContextMenuActionItem(text: self.strings.get(.shotCopy), icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                self?.copyImage()
            })),
            .action(ContextMenuActionItem(text: self.strings.get(.shotSave), icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Download"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                self?.saveImage()
            }))
        ]
        let sourceView = (view as? GlassBarButtonComponent.View)?.menuSourceView ?? view
        let contextController = makeContextController(
            presentationData: self.presentationData,
            source: .reference(AyuShotContextReferenceContentSource(sourceView: sourceView)),
            items: .single(ContextController.Items(content: .list(items))),
            recognizer: nil,
            gesture: nil
        )
        self.presentInGlobalOverlay(contextController)
    }

    private func addRow(title: String, toggle: UISwitch, isOn: Bool) {
        let row = AyuShotPreferenceRow()
        row.label.text = title
        row.label.font = UIFont.systemFont(ofSize: 17.0)
        row.label.textColor = self.theme.list.itemPrimaryTextColor
        toggle.isOn = isOn
        toggle.onTintColor = self.theme.list.itemSwitchColors.contentColor
        toggle.tintColor = self.theme.list.itemSwitchColors.frameColor
        toggle.addTarget(self, action: #selector(self.optionsChanged), for: .valueChanged)
        row.toggle = toggle
        row.addSubview(row.label)
        row.addSubview(toggle)
        self.preferencesCard.addSubview(row)
        self.rows.append(row)
    }

    @objc private func optionsChanged() {
        self.options = AyuShotOptions(showBackground: self.backgroundSwitch.isOn, showDate: self.dateSwitch.isOn)
        UserDefaults.standard.set(self.options.showBackground, forKey: AyuShotPreviewController.backgroundKey)
        UserDefaults.standard.set(self.options.showDate, forKey: AyuShotPreviewController.dateKey)
        self.renderCurrent()
    }

    private func renderCurrent() {
        let options = self.options
        if let image = self.images[options] {
            self.show(image)
            return
        }
        guard !self.isRendering else {
            return
        }
        self.isRendering = true
        self.activityView.startAnimating()
        self.imageView.alpha = 0.4
        self.updateHeaderButtons()
        self.renderer.render(in: self.displayNode.view, width: self.renderWidth, options: options, completion: { [weak self] image in
            guard let self else {
                return
            }
            self.isRendering = false
            self.activityView.stopAnimating()
            if let image {
                self.images[options] = image
            }
            if options != self.options {
                self.renderCurrent()
                return
            }
            if let image {
                self.show(image)
            } else {
                self.imageView.alpha = 1.0
                self.updateHeaderButtons()
                self.presentToast(.info(title: nil, text: self.strings.get(.shotFailed), timeout: nil, customUndoText: nil))
            }
        })
    }

    private func show(_ image: UIImage) {
        self.image = image
        self.imageView.image = image
        self.imageView.alpha = 1.0
        self.updateHeaderButtons()
        UIView.animate(withDuration: 0.25, animations: {
            self.layoutSheet()
        })
    }

    private func copyImage() {
        guard let image = self.image, let data = image.pngData() else {
            return
        }
        UIPasteboard.general.setData(data, forPasteboardType: "public.png")
        self.presentToast(.copy(text: self.strings.get(.shotCopied)))
    }

    private func saveImage() {
        guard let image = self.image, let data = image.pngData() else {
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: { [weak self] status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self?.presentFailure()
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }, completionHandler: { success, _ in
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    if success {
                        self.presentToast(.mediaSaved(text: self.strings.get(.shotSaved)))
                    } else {
                        self.presentFailure()
                    }
                }
            })
        })
    }

    private func presentFailure() {
        self.presentToast(.info(title: nil, text: self.strings.get(.shotFailed), timeout: nil, customUndoText: nil))
    }

    private func presentToast(_ content: UndoOverlayContent) {
        self.present(UndoOverlayController(presentationData: self.presentationData, content: content, elevatedLayout: false, position: .top, action: { _ in
            return false
        }), in: .current)
    }

    @objc private func closePressed() {
        guard !self.isDismissing else {
            return
        }
        self.isDismissing = true
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseIn], animations: {
            self.dimView.alpha = 0.0
            self.sheetClipView.frame.origin.y = self.displayNode.view.bounds.height
        }, completion: { [weak self] _ in
            self?.dismiss()
        })
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

private final class AyuShotPreferenceRow: UIView {
    let label = UILabel()
    var toggle: UISwitch?

    override func layoutSubviews() {
        super.layoutSubviews()
        let side: CGFloat = 16.0
        if let toggle = self.toggle {
            let toggleSize = toggle.intrinsicContentSize
            toggle.frame = CGRect(x: self.bounds.width - side - toggleSize.width, y: floor((self.bounds.height - toggleSize.height) / 2.0), width: toggleSize.width, height: toggleSize.height)
            self.label.frame = CGRect(x: side, y: 0.0, width: toggle.frame.minX - side * 2.0, height: self.bounds.height)
        } else {
            self.label.frame = CGRect(x: side, y: 0.0, width: self.bounds.width - side * 2.0, height: self.bounds.height)
        }
    }
}
