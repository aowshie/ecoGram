import Foundation
import UIKit

public let ecoSettingsIcon: UIImage = {
    let size = CGSize(width: 30.0, height: 30.0)
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
        let context = rendererContext.cgContext
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 7.0).addClip()
        let colors = [UIColor(white: 0.18, alpha: 1.0).cgColor, UIColor.black.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: [])
        }
        context.scaleBy(x: size.width / 1024.0, y: size.height / 1024.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        do {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 336.6, y: 194))
            path.addCurve(to: CGPoint(x: 224.6, y: 306), controlPoint1: CGPoint(x: 261.933, y: 194), controlPoint2: CGPoint(x: 224.6, y: 231.333))
            path.addLine(to: CGPoint(x: 224.6, y: 400))
            path.addCurve(to: CGPoint(x: 135, y: 512), controlPoint1: CGPoint(x: 224.6, y: 474.667), controlPoint2: CGPoint(x: 194.733, y: 512))
            path.addCurve(to: CGPoint(x: 224.6, y: 624), controlPoint1: CGPoint(x: 194.733, y: 512), controlPoint2: CGPoint(x: 224.6, y: 549.333))
            path.addLine(to: CGPoint(x: 224.6, y: 718))
            path.addCurve(to: CGPoint(x: 336.6, y: 830), controlPoint1: CGPoint(x: 224.6, y: 792.667), controlPoint2: CGPoint(x: 261.933, y: 830))
            path.apply(CGAffineTransform(translationX: -20.0, y: 0.0))
            path.lineWidth = 70.0
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor(white: 1.0, alpha: 0.28).setStroke()
            path.stroke()
        }
        do {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 687.6, y: 194))
            path.addCurve(to: CGPoint(x: 799.6, y: 306), controlPoint1: CGPoint(x: 762.266, y: 194), controlPoint2: CGPoint(x: 799.6, y: 231.333))
            path.addLine(to: CGPoint(x: 799.6, y: 400))
            path.addCurve(to: CGPoint(x: 889.2, y: 512), controlPoint1: CGPoint(x: 799.6, y: 474.667), controlPoint2: CGPoint(x: 829.466, y: 512))
            path.addCurve(to: CGPoint(x: 799.6, y: 624), controlPoint1: CGPoint(x: 829.466, y: 512), controlPoint2: CGPoint(x: 799.6, y: 549.333))
            path.addLine(to: CGPoint(x: 799.6, y: 718))
            path.addCurve(to: CGPoint(x: 687.6, y: 830), controlPoint1: CGPoint(x: 799.6, y: 792.667), controlPoint2: CGPoint(x: 762.266, y: 830))
            path.apply(CGAffineTransform(translationX: 20.0, y: 0.0))
            path.lineWidth = 70.0
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor(white: 1.0, alpha: 0.28).setStroke()
            path.stroke()
        }
        do {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 634.121, y: 354.612))
            path.addCurve(to: CGPoint(x: 668.664, y: 387.038), controlPoint1: CGPoint(x: 661.221, y: 345.759), controlPoint2: CGPoint(x: 677.283, y: 360.114))
            path.addCurve(to: CGPoint(x: 577.54, y: 656.054), controlPoint1: CGPoint(x: 647.028, y: 454.698), controlPoint2: CGPoint(x: 604.543, y: 578.121))
            path.addCurve(to: CGPoint(x: 529.528, y: 655.686), controlPoint1: CGPoint(x: 570.468, y: 676.438), controlPoint2: CGPoint(x: 537.744, y: 675.64))
            path.addCurve(to: CGPoint(x: 466.357, y: 552.616), controlPoint1: CGPoint(x: 515.431, y: 621.473), controlPoint2: CGPoint(x: 494.679, y: 581.645))
            path.addCurve(to: CGPoint(x: 367.676, y: 491.079), controlPoint1: CGPoint(x: 439.274, y: 524.863), controlPoint2: CGPoint(x: 401.35, y: 504.798))
            path.addCurve(to: CGPoint(x: 367.514, y: 441.731), controlPoint1: CGPoint(x: 347.167, y: 482.723), controlPoint2: CGPoint(x: 346.441, y: 448.605))
            path.addLine(to: CGPoint(x: 634.121, y: 354.607))
            path.addLine(to: CGPoint(x: 634.121, y: 354.612))
            path.close()
            path.apply(CGAffineTransform(translationX: -512.0, y: -512.0).concatenating(CGAffineTransform(scaleX: 1.1, y: 1.1)).concatenating(CGAffineTransform(translationX: 504.0, y: 522.0)))
            path.lineWidth = 76.4448 * 1.1
            path.lineJoinStyle = .round
            UIColor.white.setFill()
            UIColor.white.setStroke()
            path.fill()
            path.stroke()
        }
    }
}()
