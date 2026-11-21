import Foundation
import Postbox
import SwiftSignalKit

public struct EcoNotificationPresentation {
    public let displayContents: Bool
    public let playsSound: Bool
}

public extension TelegramEngine.Messages {
    func ecoNotificationPresentation(id: EngineMessage.Id) -> Signal<EcoNotificationPresentation, NoError> {
        return self.account.postbox.transaction { transaction -> EcoNotificationPresentation in
            let presentation = messagesForNotification(transaction: transaction, id: id, alwaysReturnMessage: true)
            return EcoNotificationPresentation(displayContents: presentation.displayContents, playsSound: presentation.sound != .none)
        }
    }
}
