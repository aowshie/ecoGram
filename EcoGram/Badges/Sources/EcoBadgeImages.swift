import Foundation
import UIKit

public enum EcoBadgeImages {
    private static let canvas: CGFloat = 1024.0
    private static let braceMirrorAxis: CGFloat = 1024.2
    private static let rosettePetalCount = 8
    private static let rosetteCoreRadius: CGFloat = 320.0
    private static let rosettePetalDistance: CGFloat = 300.0
    private static let rosettePetalRadius: CGFloat = 165.0
    private static let rosetteBracesCut: CGFloat = 0.55
    private static let lock = NSLock()
    private static var cache: [String: UIImage] = [:]

    public static func image(_ kind: EcoBadgeKind, side: CGFloat = 20.0) -> UIImage? {
        let glyph = Glyph(kind)
        let key = "\(glyph)-\(side)"
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if let cached = self.cache[key] {
            return cached
        }
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { rendererContext in
            let context = rendererContext.cgContext
            context.scaleBy(x: side / self.canvas, y: side / self.canvas)
            context.setFillColor(UIColor.white.cgColor)
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            glyph.draw(in: context)
        }.withRenderingMode(.alwaysTemplate)
        self.cache[key] = image
        return image
    }

    private enum Glyph: String {
        case developer
        case early

        init(_ kind: EcoBadgeKind) {
            switch kind {
            case .developer, .official:
                self = .developer
            case .early:
                self = .early
            }
        }

        func draw(in context: CGContext) {
            switch self {
            case .developer:
                EcoBadgeImages.stroke(EcoBadgeImages.leftBrace(offset: -28.0), width: 96.0, in: context)
                EcoBadgeImages.stroke(EcoBadgeImages.rightBrace(offset: 28.0), width: 96.0, in: context)
                EcoBadgeImages.fillAndStroke(EcoBadgeImages.plane(center: CGPoint(x: 504.0, y: 522.0), scale: 0.92), width: 76.0 * 0.92, in: context)
            case .early:
                let bracesScale: CGFloat = 0.68
                let planeScale: CGFloat = 0.62
                EcoBadgeImages.fillRosette(in: context)
                context.setBlendMode(.destinationOut)
                context.setStrokeColor(UIColor(white: 1.0, alpha: EcoBadgeImages.rosetteBracesCut).cgColor)
                EcoBadgeImages.stroke(EcoBadgeImages.scaled(EcoBadgeImages.leftBrace(offset: -28.0), by: bracesScale), width: 96.0 * bracesScale, in: context)
                EcoBadgeImages.stroke(EcoBadgeImages.scaled(EcoBadgeImages.rightBrace(offset: 28.0), by: bracesScale), width: 96.0 * bracesScale, in: context)
                context.setStrokeColor(UIColor.white.cgColor)
                context.setBlendMode(.clear)
                EcoBadgeImages.fillAndStroke(EcoBadgeImages.plane(center: CGPoint(x: 507.0, y: 520.0), scale: planeScale), width: 70.0 * planeScale, in: context)
                context.setBlendMode(.normal)
            }
        }
    }

    private static func stroke(_ path: CGPath, width: CGFloat, in context: CGContext) {
        context.setLineWidth(width)
        context.addPath(path)
        context.strokePath()
    }

    private static func fillAndStroke(_ path: CGPath, width: CGFloat, in context: CGContext) {
        context.setLineWidth(width)
        context.addPath(path)
        context.drawPath(using: .fillStroke)
    }

    private static func leftBrace(offset: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let transform = CGAffineTransform(translationX: offset, y: 0.0)
        path.move(to: CGPoint(x: 336.6, y: 194.0), transform: transform)
        path.addCurve(to: CGPoint(x: 224.6, y: 306.0), control1: CGPoint(x: 261.9, y: 194.0), control2: CGPoint(x: 224.6, y: 231.3), transform: transform)
        path.addLine(to: CGPoint(x: 224.6, y: 400.0), transform: transform)
        path.addCurve(to: CGPoint(x: 135.0, y: 512.0), control1: CGPoint(x: 224.6, y: 474.7), control2: CGPoint(x: 194.7, y: 512.0), transform: transform)
        path.addCurve(to: CGPoint(x: 224.6, y: 624.0), control1: CGPoint(x: 194.7, y: 512.0), control2: CGPoint(x: 224.6, y: 549.3), transform: transform)
        path.addLine(to: CGPoint(x: 224.6, y: 718.0), transform: transform)
        path.addCurve(to: CGPoint(x: 336.6, y: 830.0), control1: CGPoint(x: 224.6, y: 792.7), control2: CGPoint(x: 261.9, y: 830.0), transform: transform)
        return path
    }

    private static func rightBrace(offset: CGFloat) -> CGPath {
        var mirror = CGAffineTransform(translationX: self.braceMirrorAxis + offset, y: 0.0).scaledBy(x: -1.0, y: 1.0)
        return self.leftBrace(offset: 0.0).copy(using: &mirror) ?? CGMutablePath()
    }

    private static func plane(center: CGPoint, scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let transform = CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: scale, y: scale).translatedBy(x: -512.0, y: -512.0)
        path.move(to: CGPoint(x: 634.1, y: 354.6), transform: transform)
        path.addCurve(to: CGPoint(x: 668.7, y: 387.0), control1: CGPoint(x: 661.2, y: 345.8), control2: CGPoint(x: 677.3, y: 360.1), transform: transform)
        path.addCurve(to: CGPoint(x: 577.5, y: 656.1), control1: CGPoint(x: 647.0, y: 454.7), control2: CGPoint(x: 604.5, y: 578.1), transform: transform)
        path.addCurve(to: CGPoint(x: 529.5, y: 655.7), control1: CGPoint(x: 570.5, y: 676.4), control2: CGPoint(x: 537.7, y: 675.6), transform: transform)
        path.addCurve(to: CGPoint(x: 466.4, y: 552.6), control1: CGPoint(x: 515.4, y: 621.5), control2: CGPoint(x: 494.7, y: 581.6), transform: transform)
        path.addCurve(to: CGPoint(x: 367.7, y: 491.1), control1: CGPoint(x: 439.3, y: 524.9), control2: CGPoint(x: 401.4, y: 504.8), transform: transform)
        path.addCurve(to: CGPoint(x: 367.5, y: 441.7), control1: CGPoint(x: 347.2, y: 482.7), control2: CGPoint(x: 346.4, y: 448.6), transform: transform)
        path.closeSubpath()
        return path
    }

    private static func scaled(_ path: CGPath, by scale: CGFloat) -> CGPath {
        let center = self.canvas / 2.0
        var transform = CGAffineTransform(translationX: center, y: center).scaledBy(x: scale, y: scale).translatedBy(x: -center, y: -center)
        return path.copy(using: &transform) ?? path
    }

    private static func fillRosette(in context: CGContext) {
        let center = CGPoint(x: 512.0, y: 512.0)
        context.fillEllipse(in: CGRect(x: center.x - self.rosetteCoreRadius, y: center.y - self.rosetteCoreRadius, width: self.rosetteCoreRadius * 2.0, height: self.rosetteCoreRadius * 2.0))
        for index in 0 ..< self.rosettePetalCount {
            let angle = CGFloat(index) * 2.0 * .pi / CGFloat(self.rosettePetalCount)
            let petalCenter = CGPoint(x: center.x + cos(angle) * self.rosettePetalDistance, y: center.y + sin(angle) * self.rosettePetalDistance)
            context.fillEllipse(in: CGRect(x: petalCenter.x - self.rosettePetalRadius, y: petalCenter.y - self.rosettePetalRadius, width: self.rosettePetalRadius * 2.0, height: self.rosettePetalRadius * 2.0))
        }
    }
}
