import Foundation
import EcoSettingsUI

enum AyuListAction: Hashable {
    case openGhost
    case openHistory
    case openBadges
    case addException
    case deleteExceptions
    case removeException
}

typealias AyuListEntry = EcoListEntry<AyuListAction>
typealias AyuListArguments = EcoListArguments<AyuListAction>
