import Foundation
import UIKit

public let ayuSettingsIcon: UIImage = {
    let size = CGSize(width: 30.0, height: 30.0)
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
        let context = rendererContext.cgContext
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 7.0).addClip()
        UIColor(red: 0.169, green: 0.133, blue: 0.259, alpha: 1.0).setFill()
        context.fill(CGRect(origin: .zero, size: size))
        context.scaleBy(x: size.width / 1200.0, y: size.height / 1200.0)
        do {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 672.345, y: 264.951))
            path.addCurve(to: CGPoint(x: 649.404, y: 274.293), controlPoint1: CGPoint(x: 664.864, y: 253.017), controlPoint2: CGPoint(x: 646.428, y: 260.525))
            path.addLine(to: CGPoint(x: 763.463, y: 801.88))
            path.addCurve(to: CGPoint(x: 775.752, y: 811.799), controlPoint1: CGPoint(x: 764.715, y: 807.668), controlPoint2: CGPoint(x: 769.833, y: 811.799))
            path.addLine(to: CGPoint(x: 992.407, y: 811.799))
            path.addCurve(to: CGPoint(x: 1003.06, y: 792.538), controlPoint1: CGPoint(x: 1002.29, y: 811.799), controlPoint2: CGPoint(x: 1008.31, y: 800.915))
            path.addLine(to: CGPoint(x: 672.345, y: 264.951))
            path.close()
            UIColor(red: 0.765, green: 0.682, blue: 1.000, alpha: 1.0).setFill()
            path.fill()
        }
        do {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 623.939, y: 927.397))
            path.addCurve(to: CGPoint(x: 646.514, y: 935.018), controlPoint1: CGPoint(x: 623.939, y: 939.438), controlPoint2: CGPoint(x: 639.222, y: 944.597))
            path.addLine(to: CGPoint(x: 717.404, y: 841.895))
            path.addCurve(to: CGPoint(x: 719.691, y: 831.618), controlPoint1: CGPoint(x: 719.631, y: 838.969), controlPoint2: CGPoint(x: 720.467, y: 835.214))
            path.addLine(to: CGPoint(x: 648.801, y: 503.223))
            path.addCurve(to: CGPoint(x: 623.939, y: 505.878), controlPoint1: CGPoint(x: 645.62, y: 488.487), controlPoint2: CGPoint(x: 623.939, y: 490.802))
            path.addLine(to: CGPoint(x: 623.939, y: 927.397))
            path.close()
            UIColor(red: 0.863, green: 0.812, blue: 1.000, alpha: 1.0).setFill()
            path.fill()
        }
        do {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 526.655, y: 264.951))
            path.addCurve(to: CGPoint(x: 549.596, y: 274.293), controlPoint1: CGPoint(x: 534.136, y: 253.017), controlPoint2: CGPoint(x: 552.572, y: 260.525))
            path.addLine(to: CGPoint(x: 435.537, y: 801.88))
            path.addCurve(to: CGPoint(x: 423.248, y: 811.799), controlPoint1: CGPoint(x: 434.285, y: 807.668), controlPoint2: CGPoint(x: 429.167, y: 811.799))
            path.addLine(to: CGPoint(x: 206.593, y: 811.799))
            path.addCurve(to: CGPoint(x: 195.941, y: 792.538), controlPoint1: CGPoint(x: 196.709, y: 811.799), controlPoint2: CGPoint(x: 190.69, y: 800.915))
            path.addLine(to: CGPoint(x: 526.655, y: 264.951))
            path.close()
            UIColor(red: 0.961, green: 0.961, blue: 0.961, alpha: 1.0).setFill()
            path.fill()
        }
        do {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 575.061, y: 927.397))
            path.addCurve(to: CGPoint(x: 552.486, y: 935.018), controlPoint1: CGPoint(x: 575.061, y: 939.438), controlPoint2: CGPoint(x: 559.778, y: 944.597))
            path.addLine(to: CGPoint(x: 481.596, y: 841.895))
            path.addCurve(to: CGPoint(x: 479.309, y: 831.618), controlPoint1: CGPoint(x: 479.369, y: 838.969), controlPoint2: CGPoint(x: 478.533, y: 835.214))
            path.addLine(to: CGPoint(x: 550.199, y: 503.223))
            path.addCurve(to: CGPoint(x: 575.061, y: 505.878), controlPoint1: CGPoint(x: 553.38, y: 488.487), controlPoint2: CGPoint(x: 575.061, y: 490.802))
            path.addLine(to: CGPoint(x: 575.061, y: 927.397))
            path.close()
            UIColor(red: 0.961, green: 0.961, blue: 0.961, alpha: 1.0).setFill()
            path.fill()
        }
    }
}()
