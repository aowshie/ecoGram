import Foundation
import EcoPreferences

public func ecoCaptureProtection(_ isCopyProtected: Bool) -> Bool {
    return isCopyProtected && !EcoPreferences.shared.allowsProtectedScreenshots
}

public func ecoCopyProtection(_ isCopyProtected: Bool) -> Bool {
    return isCopyProtected && !EcoPreferences.shared.allowsProtectedCopy
}

public func ecoSaveProtection(_ isCopyProtected: Bool) -> Bool {
    return isCopyProtected && !EcoPreferences.shared.allowsProtectedSaving
}

public func ecoForwardsAsShot(_ isCopyProtected: Bool) -> Bool {
    return isCopyProtected && EcoPreferences.shared.forwardsProtectedAsShot
}
