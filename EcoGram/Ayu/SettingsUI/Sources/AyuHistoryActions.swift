import Foundation
import AccountContext
import AyuHistory

func ayuHistoryStore(context: AccountContext) -> AyuHistoryStore {
    return AyuHistoryStore.store(mediaBoxBasePath: context.account.postbox.mediaBox.basePath)
}
