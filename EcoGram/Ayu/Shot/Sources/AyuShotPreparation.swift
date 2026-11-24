import Foundation
import TelegramCore
import EcoBadges

private let ayuShotOwnAliasOffset: Int64 = 1 << 48
private let ayuShotBadgeFreeOffset: Int64 = 1 << 47
private let ayuShotAnonymousOffset: Int64 = 1 << 49

private enum AyuShotIdentity: Hashable {
    case peer(EnginePeer.Id)
    case signature(String)
}

private final class AyuShotAnonymizer {
    private let title: String
    private var numbers: [AyuShotIdentity: Int] = [:]

    init(title: String) {
        self.title = title
    }

    private func number(_ identity: AyuShotIdentity) -> Int {
        if let number = self.numbers[identity] {
            return number
        }
        let number = self.numbers.count + 1
        self.numbers[identity] = number
        return number
    }

    func name(_ identity: AyuShotIdentity) -> String {
        return "\(self.title) \(self.number(identity))"
    }

    func user(_ identity: AyuShotIdentity, id: EnginePeer.Id? = nil) -> TelegramUser {
        let number = self.number(identity)
        let userId = id ?? EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(ayuShotAnonymousOffset + Int64(number)))
        return TelegramUser(id: userId, accessHash: nil, firstName: self.name(identity), lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
    }

    func author(_ peer: EngineRawPeer?) -> EngineRawPeer? {
        return peer.map { self.user(.peer($0.id)) }
    }

    func peers(_ peers: EngineSimpleDictionary<EnginePeer.Id, EngineRawPeer>) -> EngineSimpleDictionary<EnginePeer.Id, EngineRawPeer> {
        var result = peers
        for (id, peer) in peers where peer is TelegramUser {
            result[id] = self.user(.peer(id), id: id)
        }
        return result
    }

    func forwardInfo(_ info: EngineMessage.ForwardInfo?) -> EngineMessage.ForwardInfo? {
        guard let info else {
            return nil
        }
        var author = self.author(info.author)
        if author == nil, let signature = info.authorSignature {
            author = self.user(.signature(signature))
        }
        return EngineMessage.ForwardInfo(author: author, source: self.author(info.source), sourceMessageId: info.sourceMessageId, date: info.date, authorSignature: nil, psaType: info.psaType, flags: info.flags)
    }
}

private final class AyuShotAliases {
    private let accountPeerId: EnginePeer.Id
    private let hidesBadges: Bool
    private var users: [EnginePeer.Id: TelegramUser] = [:]

    init?(accountPeerId: EnginePeer.Id, hidesBadges: Bool, aliasesOwn: Bool) {
        guard hidesBadges || aliasesOwn else {
            return nil
        }
        self.accountPeerId = accountPeerId
        self.hidesBadges = hidesBadges
    }

    func author(_ peer: EngineRawPeer?) -> TelegramUser? {
        guard let user = peer as? TelegramUser, self.hidesBadges || user.id == self.accountPeerId else {
            return nil
        }
        if let alias = self.users[user.id] {
            return alias
        }
        let rawId = user.id.id._internalGetInt64Value()
        let aliasRawId: Int64
        if self.hidesBadges {
            aliasRawId = rawId + ayuShotBadgeFreeOffset
        } else {
            aliasRawId = rawId + ayuShotOwnAliasOffset
            EcoTitleBadges.registerAlias(aliasRawId, for: rawId)
        }
        let aliasId = EnginePeer.Id(namespace: user.id.namespace, id: EnginePeer.Id.Id._internalFromInt64Value(aliasRawId))
        let flags = self.hidesBadges ? user.flags.subtracting([.isVerified, .isPremium]) : user.flags
        let nameColor = user.nameColor ?? .preset(PeerNameColor(rawValue: Int32(rawId % 7)))
        let alias = TelegramUser(id: aliasId, accessHash: user.accessHash, firstName: user.firstName, lastName: user.lastName, username: user.username, phone: nil, photo: user.photo, botInfo: user.botInfo, restrictionInfo: nil, flags: flags, emojiStatus: self.hidesBadges ? nil : user.emojiStatus, usernames: user.usernames, storiesHidden: user.storiesHidden, nameColor: nameColor, backgroundEmojiId: user.backgroundEmojiId, profileColor: user.profileColor, profileBackgroundEmojiId: user.profileBackgroundEmojiId, subscriberCount: nil, verificationIconFileId: self.hidesBadges ? nil : user.verificationIconFileId)
        self.users[user.id] = alias
        return alias
    }
}

struct AyuShotPreparation {
    let accountPeerId: EnginePeer.Id
    let revealsProtectedContent: Bool
    let options: AyuShotOptions
    let anonymousTitle: String

    func prepare(_ groups: [[EngineMessage]]) -> [[EngineMessage]] {
        let anonymizer = self.options.anonymous ? AyuShotAnonymizer(title: self.anonymousTitle) : nil
        let aliases = anonymizer == nil ? AyuShotAliases(accountPeerId: self.accountPeerId, hidesBadges: self.options.hideBadges, aliasesOwn: !self.options.ownOnRight) : nil
        return groups.map { messages in
            return messages.map { EngineMessage(self.prepare($0._asMessage(), anonymizer: anonymizer, aliases: aliases)) }
        }
    }

    private func prepare(_ message: EngineRawMessage, anonymizer: AyuShotAnonymizer?, aliases: AyuShotAliases?) -> EngineRawMessage {
        var raw = message
        var peers = raw.peers
        let chatPeerId = raw.id.peerId
        let isOwn = raw.author?.id == self.accountPeerId

        if self.revealsProtectedContent {
            raw = raw.withUpdatedFlags(raw.flags.subtracting(.CopyProtected))
            if let channel = peers[chatPeerId] as? TelegramChannel {
                peers[chatPeerId] = channel.withUpdatedFlags(channel.flags.subtracting(.copyProtectionEnabled))
            } else if let group = peers[chatPeerId] as? TelegramGroup {
                peers[chatPeerId] = group.updateFlags(flags: group.flags.subtracting(.copyProtectionEnabled), version: group.version)
            }
        }

        let attributes = raw.attributes.filter { attribute in
            if !self.options.showReactions && (attribute is ReactionsMessageAttribute || attribute is PendingReactionsMessageAttribute || attribute is PendingStarsReactionsMessageAttribute) {
                return false
            }
            if !self.options.showEdited && attribute is EditedMessageAttribute {
                return false
            }
            return true
        }
        raw = raw.withUpdatedAttributes(attributes)

        if let anonymizer {
            peers = anonymizer.peers(peers)
            if let author = anonymizer.author(raw.author) {
                peers[author.id] = author
                raw = raw.withUpdatedAuthor(author)
            }
            raw = raw.withUpdatedForwardInfo(anonymizer.forwardInfo(raw.forwardInfo))
            raw = self.anonymizeReplies(raw, anonymizer: anonymizer)
        } else if let author = aliases?.author(raw.author) {
            peers[author.id] = author
            raw = raw.withUpdatedAuthor(author)
        }

        if isOwn && !self.options.ownOnRight {
            raw = raw.withUpdatedFlags(raw.flags.union(.Incoming))
        }

        if chatPeerId.namespace == Namespaces.Peer.CloudUser || chatPeerId.namespace == Namespaces.Peer.SecretChat {
            let groupId = EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: chatPeerId.id)
            peers[groupId] = TelegramGroup(id: groupId, title: "", photo: [], participantCount: 2, role: .member, membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
            raw = raw.withUpdatedId(id: EngineMessage.Id(peerId: groupId, namespace: raw.id.namespace, id: raw.id.id))
        }
        return raw.withUpdatedPeers(peers)
    }

    private func anonymizeReplies(_ raw: EngineRawMessage, anonymizer: AyuShotAnonymizer) -> EngineRawMessage {
        guard !raw.associatedMessages.isEmpty else {
            return raw
        }
        var associatedMessages = raw.associatedMessages
        for (id, associated) in raw.associatedMessages {
            var updated = associated.withUpdatedPeers(anonymizer.peers(associated.peers))
            if let author = anonymizer.author(associated.author) {
                updated = updated.withUpdatedAuthor(author)
            }
            associatedMessages[id] = updated.withUpdatedForwardInfo(anonymizer.forwardInfo(associated.forwardInfo))
        }
        return EngineRawMessage(stableId: raw.stableId, stableVersion: raw.stableVersion, id: raw.id, globallyUniqueId: raw.globallyUniqueId, groupingKey: raw.groupingKey, groupInfo: raw.groupInfo, threadId: raw.threadId, timestamp: raw.timestamp, flags: raw.flags, tags: raw.tags, globalTags: raw.globalTags, localTags: raw.localTags, customTags: raw.customTags, forwardInfo: raw.forwardInfo, author: raw.author, text: raw.text, attributes: raw.attributes, media: raw.media, peers: raw.peers, associatedMessages: associatedMessages, associatedMessageIds: raw.associatedMessageIds, associatedMedia: raw.associatedMedia, associatedThreadInfo: raw.associatedThreadInfo, associatedStories: raw.associatedStories)
    }
}
