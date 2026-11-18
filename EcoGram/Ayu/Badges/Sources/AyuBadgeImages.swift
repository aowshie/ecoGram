import Foundation
import UIKit

public enum AyuBadgeImages {
    private static let canvasSize = CGSize(width: 20.0, height: 20.0)
    private static let lock = NSLock()
    private static var cache: [String: UIImage] = [:]

    public static func image(_ kind: AyuBadgeKind) -> UIImage? {
        let name: String
        switch kind {
        case .official:
            name = "AyuBadgeOfficial"
        case .supporter:
            name = "AyuBadgeSupporter"
        }
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if let cached = self.cache[name] {
            return cached
        }
        guard let glyph = UIImage(named: name), let mask = self.luminanceMask(glyph) else {
            return nil
        }
        let canvasSize = self.canvasSize
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: canvasSize, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            let rect = CGRect(x: floor((canvasSize.width - glyph.size.width) / 2.0), y: floor((canvasSize.height - glyph.size.height) / 2.0), width: glyph.size.width, height: glyph.size.height)
            context.translateBy(x: 0.0, y: canvasSize.height)
            context.scaleBy(x: 1.0, y: -1.0)
            let flippedRect = CGRect(x: rect.minX, y: canvasSize.height - rect.maxY, width: rect.width, height: rect.height)
            context.clip(to: flippedRect, mask: mask)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(flippedRect)
        }
        self.cache[name] = image
        return image
    }

    private static func luminanceMask(_ glyph: UIImage) -> CGImage? {
        guard let source = glyph.cgImage else {
            return nil
        }
        let width = source.width
        let height = source.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return nil
        }
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
