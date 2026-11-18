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
    private var accountIds = Set<AccountRecordId>()
    private var seenGroups: [String] = []

    public init(presentationData: @escaping () -> PresentationData?) {
        self.presentationData = presentationData
    }

    deinit {
        self.disposables.dispose()
    }

    public func update(accounts: [(AccountRecordId, Account)]) {
        let ids = Set(accounts.map { $0.0 })
        for id in self.accountIds.subtracting(ids) {
            self.disposables.set(nil, forKey: id)
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
        }
        self.accountIds = ids
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
            "messageId.id": message.id.id
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
        let identifier = "ecogram-\(accountId.int64)-\(message.id.peerId.toInt64())-\(message.id.namespace)-\(message.id.id)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil), withCompletionHandler: nil)
    }
}
