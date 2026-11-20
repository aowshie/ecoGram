import Foundation
import UIKit

public final class EcoBadgeStripView: UIView {
    public private(set) var badges: [EcoTitleBadge] = []
    private var imageViews: [UIImageView] = []
    private var side: CGFloat = 0.0
    private var spacing: CGFloat = 0.0

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    public func update(badges: [EcoTitleBadge], side: CGFloat, spacing: CGFloat, tintColor: UIColor) -> CGSize {
        self.badges = badges
        self.side = side
        self.spacing = spacing
        while self.imageViews.count < badges.count {
            let imageView = UIImageView()
            self.addSubview(imageView)
            self.imageViews.append(imageView)
        }
        while self.imageViews.count > badges.count {
            self.imageViews.removeLast().removeFromSuperview()
        }
        for (index, badge) in badges.enumerated() {
            let imageView = self.imageViews[index]
            imageView.image = badge.image(side: side)
            imageView.tintColor = tintColor
            imageView.frame = CGRect(x: CGFloat(index) * (side + spacing), y: 0.0, width: side, height: side)
        }
        self.isHidden = badges.isEmpty
        return CGSize(width: EcoTitleBadges.width(count: badges.count, side: side, spacing: spacing), height: badges.isEmpty ? 0.0 : side)
    }

    public func badge(at point: CGPoint, slop: CGFloat) -> EcoTitleBadge? {
        guard !self.isHidden, !self.badges.isEmpty, self.bounds.insetBy(dx: -slop, dy: -slop).contains(point) else {
            return nil
        }
        let step = self.side + self.spacing
        let index = step > 0.0 ? Int(floor((point.x + self.spacing / 2.0) / step)) : 0
        return self.badges[max(0, min(self.badges.count - 1, index))]
    }
}
