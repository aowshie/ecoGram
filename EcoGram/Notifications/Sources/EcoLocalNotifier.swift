import Foundation
import UIKit
import UserNotifications
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import LocalizedPeerData
import EcoPreferences

public final class EcoLocalNotifier {
    private let presentationData: () -> PresentationData?
    private let disposables = DisposableDict<AccountRecordId>()
    private let readDisposables = DisposableDict<AccountRecordId>()
    private var tracked: [AccountRecordId: [EnginePeer.Id: [EngineMessage.Index]]] = [:]
    private var trackedPeers: [AccountRecordId: ValuePromise<Set<EnginePeer.Id>>] = [:]
    private var accountIds = Set<AccountRecordId>()
    private var seenGroups: [String] = []

    public init(presentationData: @escaping () -> PresentationData?) {
        self.presentationData = presentationData
    }

    deinit {
        self.disposables.dispose()
        self.readDisposables.dispose()
    }

    public func update(accounts: [(AccountRecordId, Account)]) {
        let ids = Set(accounts.map { $0.0 })
        for id in self.accountIds.subtracting(ids) {
            self.disposables.set(nil, forKey: id)
            self.readDisposables.set(nil, forKey: id)
            self.tracked[id] = nil
            self.trackedPeers[id] = nil
        }
        for (id, account) in accounts where !self.accountIds.contains(id) {
            self.disposables.set((account.stateManager.notificationMessages
            |> deliverOnMainQueue).startStrict(next: { [weak self, weak account] list in
                guard let self, let account else {
                    return
                }
                guard EcoPreferences.shared.backgroundNotifications, UIApplication.shared.applicationState != .active else {
                    return
                }
                for (messages, _, notify, _) in list {
                    guard notify, let first = messages.first else {
                        continue
                    }
                    if let groupingKey = first.groupingKey {
                        let key = "\(id.int64)_\(first.id.peerId.toInt64())_\(groupingKey)"
                        if self.seenGroups.contains(key) {
                            continue
                        }
                        self.seenGroups.append(key)
                        if self.seenGroups.count > 100 {
                            self.seenGroups.removeFirst()
                        }
                    }
                    let message = messages.first(where: { !$0.text.isEmpty }) ?? first
                    self.post(accountId: id, accountPeerId: account.peerId, message: EngineMessage(message), count: messages.count)
                }
            }), forKey: id)
            self.observeReadState(accountId: id, account: account)
        }
        self.accountIds = ids
    }

    private func observeReadState(accountId: AccountRecordId, account: Account) {
        let peers = ValuePromise<Set<EnginePeer.Id>>(Set(), ignoreRepeated: true)
        self.trackedPeers[accountId] = peers
        self.tracked[accountId] = [:]
        let engine = TelegramEngine(account: account)
        self.readDisposables.set((peers.get()
        |> mapToSignal { peerIds -> Signal<[EnginePeer.Id: EnginePeerReadCounters], NoError> in
            if peerIds.isEmpty {
                return .single([:])
            }
            return engine.data.subscribe(EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Messages.PeerReadCounters.init(id:))))
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] counters in
            self?.removeRead(accountId: accountId, counters: counters)
        }), forKey: accountId)

        UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler: { [weak self] notifications in
            let indices = notifications.compactMap { notification -> EngineMessage.Index? in
                let userInfo = notification.request.content.userInfo
                guard notification.request.identifier.hasPrefix("ecogram-"), userInfo["accountId"] as? Int64 == accountId.int64, let peerId = userInfo["peerId"] as? Int64, let namespace = userInfo["messageId.namespace"] as? Int32, let id = userInfo["messageId.id"] as? Int32, let timestamp = userInfo["timestamp"] as? Int32 else {
                    return nil
                }
                return EngineMessage.Index(id: EngineMessage.Id(peerId: EnginePeer.Id(peerId), namespace: namespace, id: id), timestamp: timestamp)
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                for index in indices {
                    self.track(accountId: accountId, index: index)
                }
            }
        })
    }

    private func track(accountId: AccountRecordId, index: EngineMessage.Index) {
        guard var peers = self.tracked[accountId] else {
            return
        }
        var indices = peers[index.id.peerId] ?? []
        if !indices.contains(index) {
            indices.append(index)
        }
        peers[index.id.peerId] = indices
        self.tracked[accountId] = peers
        self.trackedPeers[accountId]?.set(Set(peers.keys))
    }

    private func removeRead(accountId: AccountRecordId, counters: [EnginePeer.Id: EnginePeerReadCounters]) {
        guard var peers = self.tracked[accountId] else {
            return
        }
        var identifiers: [String] = []
        for (peerId, readCounters) in counters {
            guard let indices = peers[peerId] else {
                continue
            }
            let read = indices.filter { readCounters.isIncomingMessageIndexRead($0) }
            if read.isEmpty {
                continue
            }
            identifiers.append(contentsOf: read.map { EcoLocalNotifier.identifier(accountId: accountId, messageId: $0.id) })
            let remaining = indices.filter { !read.contains($0) }
            peers[peerId] = remaining.isEmpty ? nil : remaining
        }
        if identifiers.isEmpty {
            return
        }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
        self.tracked[accountId] = peers
        self.trackedPeers[accountId]?.set(Set(peers.keys))
    }

    private static func identifier(accountId: AccountRecordId, messageId: EngineMessage.Id) -> String {
        return "ecogram-\(accountId.int64)-\(messageId.peerId.toInt64())-\(messageId.namespace)-\(messageId.id)"
    }

    private func post(accountId: AccountRecordId, accountPeerId: EnginePeer.Id, message: EngineMessage, count: Int) {
        guard let presentationData = self.presentationData() else {
            return
        }
        if message.author?.id == accountPeerId {
            return
        }
        let strings = presentationData.strings
        let order = presentationData.nameDisplayOrder
        let chatPeer = message.peers[message.id.peerId].flatMap { EnginePeer($0) }
        let authorTitle = message.author?.displayTitle(strings: strings, displayOrder: order) ?? ""
        var title = authorTitle
        var prefix = ""
        var category = "r"
        if let chatPeer {
            switch chatPeer {
            case .user, .secretChat:
                break
            case let .channel(channel):
                title = chatPeer.displayTitle(strings: strings, displayOrder: order)
                if case .group = channel.info {
                    category = "gr"
                    if !authorTitle.isEmpty {
                        prefix = authorTitle + ": "
                    }
                } else {
                    category = "c"
                }
            default:
                category = "gr"
                title = chatPeer.displayTitle(strings: strings, displayOrder: order)
                if !authorTitle.isEmpty {
                    prefix = authorTitle + ": "
                }
            }
        }
        let description = descriptionStringForMessage(contentSettings: ContentSettings.default, message: message, strings: strings, nameDisplayOrder: order, dateTimeFormat: presentationData.dateTimeFormat, accountPeerId: accountPeerId).0.string
        var body = prefix + description
        if count > 1 {
            body += " (+\(count - 1))"
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        content.threadIdentifier = "ecogram-\(accountId.int64)-\(message.id.peerId.toInt64())"
        var userInfo: [AnyHashable: Any] = [
            "accountId": accountId.int64,
            "peerId": message.id.peerId.toInt64(),
            "messageId.namespace": message.id.namespace,
            "messageId.id": message.id.id,
            "timestamp": message.timestamp
        ]
        if let threadId = message.threadId, case let .channel(channel) = chatPeer, channel.isForumOrMonoForum {
            userInfo["threadId"] = threadId
        }
        content.userInfo = userInfo
        let isMuted = message.attributes.contains(where: { attribute in
            if let attribute = attribute as? NotificationInfoMessageAttribute {
                return attribute.flags.contains(.muted)
            }
            return false
        })
        if !isMuted {
            content.sound = .default
        }
        let identifier = EcoLocalNotifier.identifier(accountId: accountId, messageId: message.id)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil), withCompletionHandler: nil)
        self.track(accountId: accountId, index: message.index)
    }
}
