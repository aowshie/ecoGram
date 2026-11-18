import Foundation
import Postbox
import SwiftSignalKit

public final class AyuDeletedMessageAttribute: MessageAttribute {
    public let date: Int32

    public init(date: Int32) {
        self.date = date
    }

    public init(decoder: PostboxDecoder) {
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.date, forKey: "d")
    }
}

public extension Message {
    var ayuIsDeleted: Bool {
        return self.attributes.contains(where: { $0 is AyuDeletedMessageAttribute })
    }
}

public extension TelegramEngine.Messages {
    func ayuDeleteKeptMessages(ids: [EngineMessage.Id]) -> Signal<Never, NoError> {
        let mediaBox = self.account.postbox.mediaBox
        return self.account.postbox.transaction { transaction -> Void in
            let kept = ids.filter { transaction.getMessage($0)?.ayuIsDeleted == true }
            if !kept.isEmpty {
                _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: kept)
            }
        }
        |> ignoreValues
    }
}
