import Foundation
import UIKit
import Display
import TelegramCore
import EcoStrings

extension AyuKeptCategory {
    var color: UIColor {
        switch self {
        case .messages:
            return UIColor(rgb: 0x3478F6)
        case .media:
            return UIColor(rgb: 0x5AC8FA)
        case .disappearing:
            return UIColor(rgb: 0xFF2D55)
        case .edits:
            return UIColor(rgb: 0xFF9500)
        }
    }

    var particle: String {
        switch self {
        case .messages:
            return "Settings/Storage/ParticleDocuments"
        case .media:
            return "Settings/Storage/ParticlePhotos"
        case .disappearing:
            return "Settings/Storage/ParticleVideos"
        case .edits:
            return "Settings/Storage/ParticleOther"
        }
    }

    func title(strings: EcoStrings) -> String {
        switch self {
        case .messages:
            return strings.get(.usageMessages)
        case .media:
            return strings.get(.usageMedia)
        case .disappearing:
            return strings.get(.usageDisappearing)
        case .edits:
            return strings.get(.usageEdits)
        }
    }
}

extension AyuKeptStorage {
    func clearedSize(categories: Set<AyuKeptCategory>) -> Int64 {
        var cleared = categories
        if cleared.contains(.messages) {
            cleared.insert(.media)
        }
        return cleared.reduce(Int64(0)) { result, category in
            return result + (self.sizes[category] ?? 0)
        }
    }
}
