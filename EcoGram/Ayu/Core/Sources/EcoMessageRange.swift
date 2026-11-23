import Foundation
import Postbox
import SwiftSignalKit

public extension TelegramEngine.Messages {
    func ecoMessageIds(from id: EngineMessage.Id, threadId: Int64?, limit: Int) -> Signal<[EngineMessage.Id], NoError> {
        return self.account.postbox.transaction { transaction -> [EngineMessage.Id] in
            guard let message = transaction.getMessage(id) else {
                return []
            }
            let to = MessageIndex.upperBound(peerId: id.peerId, namespace: id.namespace)
            let messages: [Message]
            if let threadId {
                messages = transaction.getMessagesWithThreadId(peerId: id.peerId, namespace: id.namespace, threadId: threadId, from: message.index, includeFrom: true, to: to, limit: limit)
            } else {
                messages = transaction.getMessages(peerId: id.peerId, namespace: id.namespace, from: message.index, includeFrom: true, to: to, limit: limit)
            }
            return messages.map { $0.id }
        }
    }
}
