import Foundation
import UIKit

public enum AyuBadgeImages {
    private static let baseSide: CGFloat = 20.0
    private static let lock = NSLock()
    private static var cache: [String: UIImage] = [:]

    public static func image(_ kind: AyuBadgeKind, side: CGFloat = 20.0) -> UIImage? {
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
        let key = "\(name)-\(side)"
        if let cached = self.cache[key] {
            return cached
        }
        guard let glyph = UIImage(named: name), let mask = self.luminanceMask(glyph) else {
            return nil
        }
        let canvasSize = CGSize(width: side, height: side)
        let factor = side / self.baseSide
        let glyphSize = CGSize(width: glyph.size.width * factor, height: glyph.size.height * factor)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: canvasSize, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            let rect = CGRect(x: (canvasSize.width - glyphSize.width) / 2.0, y: (canvasSize.height - glyphSize.height) / 2.0, width: glyphSize.width, height: glyphSize.height)
            context.translateBy(x: 0.0, y: canvasSize.height)
            context.scaleBy(x: 1.0, y: -1.0)
            let flippedRect = CGRect(x: rect.minX, y: canvasSize.height - rect.maxY, width: rect.width, height: rect.height)
            context.clip(to: flippedRect, mask: mask)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(flippedRect)
        }
        self.cache[key] = image
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
