import Foundation
import EcoPreferences

public func ecoCaptureProtection(_ isCopyProtected: Bool) -> Bool {
    return isCopyProtected && !EcoPreferences.shared.allowsProtectedScreenshots
}
