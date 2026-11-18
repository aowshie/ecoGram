import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import AyuHistory

func ayuHistoryStore(context: AccountContext) -> AyuHistoryStore {
    return AyuHistoryStore.store(mediaBoxBasePath: context.account.postbox.mediaBox.basePath)
}

private func ayuDeleteKeptMessages(context: AccountContext, records: [AyuHistoryRecord]) {
    let ids = records.filter { $0.kind == .deleted }.map { record in
        EngineMessage.Id(peerId: EnginePeer.Id(record.peerId), namespace: Namespaces.Message.Cloud, id: record.messageId)
    }
    if !ids.isEmpty {
        let _ = context.engine.messages.ayuDeleteKeptMessages(ids: ids).startStandalone()
    }
}

func ayuExpireHistory(context: AccountContext) {
    ayuHistoryStore(context: context).expire { expired in
        ayuDeleteKeptMessages(context: context, records: expired)
    }
}

func ayuClearDeleted(context: AccountContext) {
    ayuHistoryStore(context: context).remove(kind: .deleted) { removed in
        ayuDeleteKeptMessages(context: context, records: removed)
    }
}
