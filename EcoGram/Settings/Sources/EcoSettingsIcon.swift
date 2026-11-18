import Foundation
import UIKit

public let ecoSettingsIcon: UIImage = {
    let size = CGSize(width: 30.0, height: 30.0)
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
        let context = rendererContext.cgContext
        let bounds = CGRect(origin: .zero, size: size)
        UIBezierPath(roundedRect: bounds, cornerRadius: 7.0).addClip()

        let colors = [UIColor(white: 0.18, alpha: 1.0).cgColor, UIColor.black.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: [])
        }

        let braces = NSAttributedString(string: "{ }", attributes: [
            .font: UIFont.systemFont(ofSize: 19.0, weight: .semibold),
            .foregroundColor: UIColor(white: 1.0, alpha: 0.32)
        ])
        let bracesSize = braces.size()
        braces.draw(at: CGPoint(x: floor((size.width - bracesSize.width) / 2.0), y: floor((size.height - bracesSize.height) / 2.0) - 0.5))

        let configuration = UIImage.SymbolConfiguration(pointSize: 11.0, weight: .bold)
        if let plane = UIImage(systemName: "paperplane.fill", withConfiguration: configuration)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
            plane.draw(at: CGPoint(x: floor((size.width - plane.size.width) / 2.0), y: floor((size.height - plane.size.height) / 2.0)))
        }
    }
}()
