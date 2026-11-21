import Foundation
import Postbox
internal import TelegramApi
import SwiftSignalKit
import AyuSettings

func ayuSuppressesContentRead(peerId: PeerId) -> Bool {
    return AyuSettings.shared.suppressReadReceipts(peerId: peerId.toInt64())
}

func ayuReadOnInteract(account: Account, peerId: PeerId) {
    guard AyuSettings.shared.readsOnInteract(peerId: peerId.toInt64()) else {
        return
    }
    guard peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudChannel else {
        return
    }
    let network = account.network
    let stateManager: AccountStateManager = account.stateManager
    let _ = (account.postbox.transaction { transaction -> (Api.InputPeer, Int32)? in
        guard let peer = transaction.getPeer(peerId), peerKeepsReadState(peer), let inputPeer = apiInputPeer(peer) else {
            return nil
        }
        guard let index = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) else {
            return nil
        }
        let _ = transaction.applyInteractiveReadMaxIndex(index)
        stateManager.notifyAppliedIncomingReadMessages([index.id])
        return (inputPeer, index.id.id)
    }
    |> mapToSignal { value -> Signal<Never, NoError> in
        guard let (inputPeer, maxId) = value else {
            return .complete()
        }
        if case let .inputPeerChannel(channelData) = inputPeer {
            return network.request(Api.functions.channels.readHistory(channel: Api.InputChannel.inputChannel(.init(channelId: channelData.channelId, accessHash: channelData.accessHash)), maxId: maxId))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .complete()
            }
            |> ignoreValues
        }
        return network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: maxId))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            if let result {
                switch result {
                case let .affectedMessages(affectedMessagesData):
                    stateManager.addUpdateGroups([.updatePts(pts: affectedMessagesData.pts, ptsCount: affectedMessagesData.ptsCount)])
                }
            }
            return .complete()
        }
    }).startStandalone()
}
