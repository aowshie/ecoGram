import Foundation
import UIKit
import EcoStrings

final class AyuShotPreviewController: UIViewController {
    private let image: UIImage
    private let strings: EcoStrings
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let toastLabel = UILabel()

    init(image: UIImage, strings: EcoStrings) {
        self.image = image
        self.strings = strings
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overFullScreen
        self.modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterialDark))
        blur.frame = self.view.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(blur)

        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.scrollView)

        self.imageView.image = self.image
        self.imageView.contentMode = .scaleAspectFit
        self.imageView.layer.cornerRadius = 22.0
        self.imageView.layer.cornerCurve = .continuous
        self.imageView.clipsToBounds = true
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.addSubview(self.imageView)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15.0, weight: .semibold)), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor(white: 1.0, alpha: 0.16)
        closeButton.layer.cornerRadius = 18.0
        closeButton.accessibilityLabel = self.strings.get(.shotClose)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)
        self.view.addSubview(closeButton)

        let saveButton = self.makeButton(title: self.strings.get(.shotSave), systemImage: "square.and.arrow.down", filled: true, action: #selector(self.savePressed))
        let shareButton = self.makeButton(title: self.strings.get(.shotShare), systemImage: "square.and.arrow.up", filled: false, action: #selector(self.sharePressed))
        let buttons = UIStackView(arrangedSubviews: [saveButton, shareButton])
        buttons.axis = .horizontal
        buttons.spacing = 12.0
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(buttons)

        self.toastLabel.text = self.strings.get(.shotSaved)
        self.toastLabel.font = UIFont.systemFont(ofSize: 15.0, weight: .semibold)
        self.toastLabel.textColor = .white
        self.toastLabel.textAlignment = .center
        self.toastLabel.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
        self.toastLabel.layer.cornerRadius = 16.0
        self.toastLabel.clipsToBounds = true
        self.toastLabel.alpha = 0.0
        self.toastLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.toastLabel)

        let guide = self.view.safeAreaLayoutGuide
        let aspect = self.image.size.height / max(self.image.size.width, 1.0)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8.0),
            closeButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16.0),
            closeButton.widthAnchor.constraint(equalToConstant: 36.0),
            closeButton.heightAnchor.constraint(equalToConstant: 36.0),

            buttons.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16.0),
            buttons.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16.0),
            buttons.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12.0),
            buttons.heightAnchor.constraint(equalToConstant: 50.0),

            self.scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 12.0),
            self.scrollView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12.0),

            self.imageView.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor, constant: 8.0),
            self.imageView.bottomAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.bottomAnchor, constant: -8.0),
            self.imageView.leadingAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.leadingAnchor, constant: 16.0),
            self.imageView.trailingAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.trailingAnchor, constant: -16.0),
            self.imageView.heightAnchor.constraint(equalTo: self.imageView.widthAnchor, multiplier: aspect),

            self.toastLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            self.toastLabel.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -16.0),
            self.toastLabel.heightAnchor.constraint(equalToConstant: 32.0),
            self.toastLabel.widthAnchor.constraint(equalToConstant: 220.0)
        ])
    }

    private func makeButton(title: String, systemImage: String, filled: Bool, action: Selector) -> UIButton {
        var configuration: UIButton.Configuration = filled ? .filled() : .tinted()
        configuration.title = title
        configuration.image = UIImage(systemName: systemImage)
        configuration.imagePadding = 8.0
        configuration.cornerStyle = .large
        configuration.baseBackgroundColor = filled ? .white : UIColor(white: 1.0, alpha: 0.18)
        configuration.baseForegroundColor = filled ? .black : .white
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func closePressed() {
        self.dismiss(animated: true)
    }

    @objc private func savePressed() {
        UIImageWriteToSavedPhotosAlbum(self.image, nil, nil, nil)
        UIView.animate(withDuration: 0.2, animations: {
            self.toastLabel.alpha = 1.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.4, options: [], animations: {
                self.toastLabel.alpha = 0.0
            })
        })
    }

    @objc private func sharePressed(_ sender: UIButton) {
        let activityController = UIActivityViewController(activityItems: [self.image], applicationActivities: nil)
        activityController.popoverPresentationController?.sourceView = sender
        activityController.popoverPresentationController?.sourceRect = sender.bounds
        self.present(activityController, animated: true)
    }
}
