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
        guard let glyph = UIImage(named: name) else {
            return nil
        }
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: self.canvasSize, format: format).image { _ in
            let origin = CGPoint(x: floor((self.canvasSize.width - glyph.size.width) / 2.0), y: floor((self.canvasSize.height - glyph.size.height) / 2.0))
            glyph.draw(in: CGRect(origin: origin, size: glyph.size))
        }
        self.cache[name] = image
        return image
    }
}
