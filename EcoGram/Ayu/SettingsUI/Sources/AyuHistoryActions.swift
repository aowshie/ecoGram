import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import AyuHistory

func ayuHistoryStore(context: AccountContext) -> AyuHistoryStore {
    return AyuHistoryStore.store(mediaBoxBasePath: context.account.postbox.mediaBox.basePath)
}

private func ayuDeleteKeptMessages(context: AccountContext, records: [AyuHistoryRecord]) {
    let ids = records.filter { $0.kind == .deleted || $0.kind == .expired }.map { record in
        EngineMessage.Id(peerId: EnginePeer.Id(record.peerId), namespace: Namespaces.Message.Cloud, id: record.messageId)
    }
    if !ids.isEmpty {
        let _ = context.engine.messages.ayuDeleteKeptMessages(ids: ids).startStandalone()
    }
}

public func ayuExpireHistory(context: AccountContext) {
    ayuHistoryStore(context: context).expire { expired in
        ayuDeleteKeptMessages(context: context, records: expired)
    }
}

func ayuClearDeleted(context: AccountContext) {
    let store = ayuHistoryStore(context: context)
    store.remove(kind: .deleted) { removed in
        ayuDeleteKeptMessages(context: context, records: removed)
    }
    store.remove(kind: .expired) { removed in
        ayuDeleteKeptMessages(context: context, records: removed)
    }
}
