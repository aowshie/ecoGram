import Foundation
import UIKit
import Photos
import TelegramPresentationData
import ComponentFlow
import GlassBarButtonComponent
import BundleIconComponent
import AppBundle
import AccountContext
import EcoStrings

final class AyuShotPreviewController: UIViewController {
    private static let backgroundKey = "ecogram.shot.showBackground"
    private static let dateKey = "ecogram.shot.showDate"
    private static let rowHeight: CGFloat = 52.0
    private static let headerHeight: CGFloat = 68.0
    private static let buttonSize: CGFloat = 44.0

    private let renderer: AyuShotRenderer
    private let renderWidth: CGFloat
    private let theme: PresentationTheme
    private let strings: EcoStrings

    private var options: AyuShotOptions
    private var images: [AyuShotOptions: UIImage] = [:]
    private var isRendering = false
    private var image: UIImage?

    private let dimView = UIView()
    private let sheetView = UIView()
    private let titleLabel = UILabel()
    private let closeButton = ComponentView<Empty>()
    private let moreButton = ComponentView<Empty>()
    private let moreMenuButton = UIButton(type: .custom)
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let activityView = UIActivityIndicatorView(style: .medium)
    private let preferencesLabel = UILabel()
    private let preferencesCard = UIView()
    private let backgroundSwitch = UISwitch()
    private let dateSwitch = UISwitch()
    private let toastLabel = UILabel()
    private var didAppear = false

    init(context: AccountContext, renderer: AyuShotRenderer, renderWidth: CGFloat) {
        self.renderer = renderer
        self.renderWidth = renderWidth
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.theme = presentationData.theme
        self.strings = EcoStrings(languageCode: presentationData.strings.baseLanguageCode)
        let defaults = UserDefaults.standard
        self.options = AyuShotOptions(
            showBackground: defaults.object(forKey: AyuShotPreviewController.backgroundKey) as? Bool ?? true,
            showDate: defaults.object(forKey: AyuShotPreviewController.dateKey) as? Bool ?? false
        )
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overFullScreen
        self.modalPresentationCapturesStatusBarAppearance = true
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let list = self.theme.list
        self.view.backgroundColor = .clear

        self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        self.dimView.alpha = 0.0
        self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.closePressed)))
        self.view.addSubview(self.dimView)

        self.sheetView.backgroundColor = list.blocksBackgroundColor
        self.sheetView.layer.cornerRadius = 38.0
        self.sheetView.layer.cornerCurve = .continuous
        self.sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        self.sheetView.clipsToBounds = true
        self.view.addSubview(self.sheetView)

        self.titleLabel.text = self.strings.get(.actionShot)
        self.titleLabel.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        self.titleLabel.textColor = list.itemPrimaryTextColor
        self.titleLabel.textAlignment = .center
        self.sheetView.addSubview(self.titleLabel)

        self.moreMenuButton.accessibilityLabel = self.strings.get(.shotCopy)
        self.moreMenuButton.showsMenuAsPrimaryAction = true
        self.moreMenuButton.menu = UIMenu(children: [
            UIAction(title: self.strings.get(.shotCopy), image: UIImage(bundleImageName: "Chat/Context Menu/Copy")?.withRenderingMode(.alwaysTemplate), handler: { [weak self] _ in
                self?.copyImage()
            }),
            UIAction(title: self.strings.get(.shotSave), image: UIImage(bundleImageName: "Chat/Context Menu/Download")?.withRenderingMode(.alwaysTemplate), handler: { [weak self] _ in
                self?.saveImage()
            })
        ])

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

        self.addRow(title: self.strings.get(.shotShowBackground), toggle: self.backgroundSwitch, index: 0, isOn: self.options.showBackground)
        self.addRow(title: self.strings.get(.shotShowDate), toggle: self.dateSwitch, index: 1, isOn: self.options.showDate)
        let separator = UIView()
        separator.backgroundColor = list.itemBlocksSeparatorColor
        separator.tag = 100
        self.preferencesCard.addSubview(separator)

        self.toastLabel.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
        self.toastLabel.textColor = .white
        self.toastLabel.textAlignment = .center
        self.toastLabel.backgroundColor = UIColor(white: 0.0, alpha: 0.75)
        self.toastLabel.layer.cornerRadius = 20.0
        self.toastLabel.layer.cornerCurve = .continuous
        self.toastLabel.clipsToBounds = true
        self.toastLabel.alpha = 0.0
        self.view.addSubview(self.toastLabel)

        self.updateButtons()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = self.view.bounds
        let insets = self.view.safeAreaInsets
        self.dimView.frame = bounds

        let side: CGFloat = 16.0
        let cardHeight = AyuShotPreviewController.rowHeight * 2.0
        let preferencesHeight: CGFloat = 32.0 + cardHeight
        let bottomInset = max(insets.bottom, 16.0)
        let maxSheetHeight = bounds.height - insets.top - 12.0
        let imageWidth = bounds.width - side * 2.0
        var imageHeight: CGFloat = 220.0
        if let image = self.image, image.size.width > 0.0 {
            imageHeight = ceil(imageWidth * image.size.height / image.size.width)
        }
        let fixedHeight = AyuShotPreviewController.headerHeight + 8.0 + preferencesHeight + 16.0 + bottomInset
        let scrollHeight = min(imageHeight, max(120.0, maxSheetHeight - fixedHeight))
        let sheetHeight = fixedHeight + scrollHeight
        let sheetOrigin = self.didAppear ? bounds.height - sheetHeight : bounds.height
        self.sheetView.frame = CGRect(x: 0.0, y: sheetOrigin, width: bounds.width, height: sheetHeight)

        let buttonSize = AyuShotPreviewController.buttonSize
        let buttonY = floor((AyuShotPreviewController.headerHeight - buttonSize) / 2.0)
        self.updateHeaderButtons()
        self.closeButton.view?.frame = CGRect(x: side, y: buttonY, width: buttonSize, height: buttonSize)
        let moreFrame = CGRect(x: bounds.width - side - buttonSize, y: buttonY, width: buttonSize, height: buttonSize)
        self.moreButton.view?.frame = moreFrame
        self.moreMenuButton.frame = moreFrame
        self.titleLabel.frame = CGRect(x: side + buttonSize + 8.0, y: 0.0, width: bounds.width - (side + buttonSize + 8.0) * 2.0, height: AyuShotPreviewController.headerHeight)

        self.scrollView.frame = CGRect(x: 0.0, y: AyuShotPreviewController.headerHeight, width: bounds.width, height: scrollHeight)
        self.imageView.frame = CGRect(x: side, y: 0.0, width: imageWidth, height: imageHeight)
        self.scrollView.contentSize = CGSize(width: bounds.width, height: imageHeight)
        self.activityView.center = CGPoint(x: self.scrollView.frame.midX, y: self.scrollView.frame.midY)

        let preferencesTop = self.scrollView.frame.maxY + 8.0
        self.preferencesLabel.frame = CGRect(x: side * 2.0, y: preferencesTop + 8.0, width: bounds.width - side * 4.0, height: 18.0)
        self.preferencesCard.frame = CGRect(x: side, y: preferencesTop + 32.0, width: bounds.width - side * 2.0, height: cardHeight)
        for subview in self.preferencesCard.subviews {
            if subview.tag == 100 {
                subview.frame = CGRect(x: side, y: AyuShotPreviewController.rowHeight - 0.33, width: self.preferencesCard.bounds.width - side, height: 0.33)
            } else if let row = subview as? AyuShotPreferenceRow {
                row.frame = CGRect(x: 0.0, y: CGFloat(row.index) * AyuShotPreviewController.rowHeight, width: self.preferencesCard.bounds.width, height: AyuShotPreviewController.rowHeight)
            }
        }

        self.toastLabel.sizeToFit()
        let toastSize = CGSize(width: self.toastLabel.bounds.width + 32.0, height: 40.0)
        self.toastLabel.frame = CGRect(x: floor((bounds.width - toastSize.width) / 2.0), y: max(insets.top, 20.0) + 8.0, width: toastSize.width, height: toastSize.height)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !self.didAppear else {
            return
        }
        self.didAppear = true
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            self.dimView.alpha = 1.0
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        })
        self.renderCurrent()
    }

    private func updateHeaderButtons() {
        let size = CGSize(width: AyuShotPreviewController.buttonSize, height: AyuShotPreviewController.buttonSize)
        let isDark = self.theme.overallDarkAppearance
        let iconColor = self.theme.chat.inputPanel.panelControlColor
        let isEnabled = self.image != nil && !self.isRendering
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
                isEnabled: isEnabled,
                component: AnyComponentWithIdentity(id: "more", component: AnyComponent(BundleIconComponent(name: "Chat/Context Menu/More", tintColor: iconColor))),
                action: nil
            )),
            environment: {},
            containerSize: size
        )
        if let view = self.closeButton.view, view.superview == nil {
            self.sheetView.addSubview(view)
        }
        if let view = self.moreButton.view, view.superview == nil {
            self.sheetView.addSubview(view)
            self.sheetView.addSubview(self.moreMenuButton)
        }
        self.moreMenuButton.isEnabled = isEnabled
    }

    private func addRow(title: String, toggle: UISwitch, index: Int, isOn: Bool) {
        let row = AyuShotPreferenceRow(index: index)
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
        self.updateButtons()
        self.renderer.render(in: self.view, width: self.renderWidth, options: options, completion: { [weak self] image in
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
                self.updateButtons()
                self.showToast(self.strings.get(.shotFailed))
            }
        })
    }

    private func show(_ image: UIImage) {
        self.image = image
        self.imageView.image = image
        self.imageView.alpha = 1.0
        self.updateButtons()
        UIView.animate(withDuration: 0.25, animations: {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        })
    }

    private func updateButtons() {
        if self.isViewLoaded {
            self.updateHeaderButtons()
        }
    }

    private func copyImage() {
        guard let image = self.image, let data = image.pngData() else {
            return
        }
        UIPasteboard.general.setData(data, forPasteboardType: "public.png")
        self.showToast(self.strings.get(.shotCopied))
    }

    private func saveImage() {
        guard let image = self.image, let data = image.pngData() else {
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly, handler: { [weak self] status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self?.showToast(self?.strings.get(.shotFailed) ?? "")
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
                    self.showToast(self.strings.get(success ? .shotSaved : .shotFailed))
                }
            })
        })
    }

    private func showToast(_ text: String) {
        self.toastLabel.text = text
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        self.toastLabel.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.2, animations: {
            self.toastLabel.alpha = 1.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.6, options: [.beginFromCurrentState], animations: {
                self.toastLabel.alpha = 0.0
            })
        })
    }

    @objc private func closePressed() {
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseIn], animations: {
            self.dimView.alpha = 0.0
            self.sheetView.frame.origin.y = self.view.bounds.height
        }, completion: { _ in
            self.dismiss(animated: false)
        })
    }
}

private final class AyuShotPreferenceRow: UIView {
    let index: Int
    let label = UILabel()
    var toggle: UISwitch?

    init(index: Int) {
        self.index = index
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        return nil
    }

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
