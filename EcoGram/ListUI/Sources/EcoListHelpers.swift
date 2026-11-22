import Foundation
import UIKit
import Display
import SwiftSignalKit
import AppBundle
import TelegramPresentationData
import EcoStrings

public func ecoCountLabel(_ strings: EcoStrings, enabled: Int, total: Int) -> String {
    return String(format: strings.get(.ghostEnabledCount), enabled, total)
}

public func ecoStateLabel(_ presentationStrings: PresentationStrings, enabled: Int, total: Int) -> String {
    if enabled == total {
        return presentationStrings.Notifications_On
    }
    if enabled == 0 {
        return presentationStrings.Notifications_Off
    }
    return ""
}

private let ecoIconCache = Atomic<[String: UIImage]>(value: [:])

public func ecoOutlineIcon(_ name: String, color: UIColor) -> UIImage? {
    return ecoCategoryIcon(key: name, color: color, image: { UIImage(bundleImageName: name) })
}

public func ecoCategoryIcon(key: String, color: UIColor, image: () -> UIImage?) -> UIImage? {
    let cacheKey = "\(key).\(color.argb)"
    if let cached = ecoIconCache.with({ $0[cacheKey] }) {
        return cached
    }
    guard let tinted = generateTintedImage(image: image(), color: color) else {
        return nil
    }
    let result = generateImage(CGSize(width: 30.0, height: 30.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        UIGraphicsPushContext(context)
        tinted.draw(at: CGPoint(x: floor((size.width - tinted.size.width) / 2.0), y: floor((size.height - tinted.size.height) / 2.0)))
        UIGraphicsPopContext()
    })
    if let result {
        let _ = ecoIconCache.modify { cache in
            var cache = cache
            cache[cacheKey] = result
            return cache
        }
    }
    return result
}
