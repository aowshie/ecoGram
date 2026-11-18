import Foundation

public struct EcoStrings {
    public enum Key: CaseIterable {
        case settingsTitle
        case ghostHeader
        case ghostMode
        case ghostHideRead
        case ghostHideOnline
        case ghostHideTyping
        case ghostHideStoryViews
        case ghostFooter
        case historyHeader
        case historySaveDeleted
        case historySaveEdited
        case historySaveBots
        case historyMediaLimit
        case historyMediaOff
        case historyCleanup
        case historyCleanupNever
        case historyOpen
        case historyFooter
        case badgesHeader
        case badgesShow
        case badgesFooter
        case notificationsHeader
        case notificationsBackground
        case notificationsFooter
        case savedTitle
        case savedEmpty
        case savedUsage
        case savedClearAll
        case savedClearAllConfirm
        case savedClearChat
        case savedClearChatConfirm
        case savedDeleted
        case savedEdited
        case savedWas
        case savedNow
        case savedCopy
        case savedOpenMedia
        case savedDelete
        case savedMediaNotSaved
        case mediaPhoto
        case mediaVideo
        case mediaRoundVideo
        case mediaVoice
        case mediaAudio
        case mediaSticker
        case mediaAnimation
        case mediaFile
        case mediaOther
        case unitMegabytes
        case unitDays
        case unitMonth
        case unitMonths
        case unitYear
    }

    private static let table: [Key: (en: String, ru: String, ja: String)] = [
        .settingsTitle: ("ecoGram", "ecoGram", "ecoGram"),
        .ghostHeader: ("GHOST MODE", "РЕЖИМ ПРИЗРАКА", "ゴーストモード"),
        .ghostMode: ("Ghost Mode", "Режим призрака", "ゴーストモード"),
        .ghostHideRead: ("Don't Send Read Receipts", "Не отправлять прочтение", "既読を送信しない"),
        .ghostHideOnline: ("Don't Send Online Status", "Не показывать онлайн", "オンライン状態を送信しない"),
        .ghostHideTyping: ("Don't Send Typing Status", "Не показывать «печатает»", "入力中を送信しない"),
        .ghostHideStoryViews: ("Don't Mark Stories as Viewed", "Не отмечать истории просмотренными", "ストーリーを既読にしない"),
        .ghostFooter: ("Others won't see that you are online, typing or reading their messages.", "Собеседники не увидят, что вы в сети, печатаете или прочитали их сообщения.", "相手にオンライン、入力中、既読であることが表示されません。"),
        .historyHeader: ("MESSAGE HISTORY", "ИСТОРИЯ СООБЩЕНИЙ", "メッセージ履歴"),
        .historySaveDeleted: ("Save Deleted Messages", "Сохранять удалённые", "削除されたメッセージを保存"),
        .historySaveEdited: ("Save Edit History", "Сохранять историю изменений", "編集履歴を保存"),
        .historySaveBots: ("Include Chats with Bots", "Включая чаты с ботами", "ボットとのチャットも含める"),
        .historyMediaLimit: ("Save Media up To", "Сохранять медиа до", "メディアの保存上限"),
        .historyMediaOff: ("Don't Save", "Не сохранять", "保存しない"),
        .historyCleanup: ("Delete Older Than", "Удалять старше", "古い履歴を削除"),
        .historyCleanupNever: ("Never", "Никогда", "削除しない"),
        .historyOpen: ("Saved Messages History", "Сохранённая история", "保存された履歴"),
        .historyFooter: ("Deleted and edited messages are kept only on this device and never leave it.", "Удалённые и изменённые сообщения хранятся только на этом устройстве и никуда не отправляются.", "削除・編集されたメッセージはこの端末にのみ保存され、外部に送信されません。"),
        .badgesHeader: ("BADGES", "ЗНАЧКИ", "バッジ"),
        .badgesShow: ("AyuGram Badges", "Значки AyuGram", "AyuGramバッジ"),
        .badgesFooter: ("Shows the badges of AyuGram developers and supporters next to their names. The public list is downloaded from the AyuGram server, nothing is sent.", "Показывает значки разработчиков и поддержавших AyuGram рядом с именем. Публичный список загружается с сервера AyuGram, от вас ничего не отправляется.", "AyuGramの開発者と支援者のバッジを名前の横に表示します。公開リストをAyuGramのサーバーから取得し、こちらからは何も送信しません。"),
        .notificationsHeader: ("NOTIFICATIONS", "УВЕДОМЛЕНИЯ", "通知"),
        .notificationsBackground: ("Background Notifications", "Уведомления в фоне", "バックグラウンド通知"),
        .notificationsFooter: ("Keeps ecoGram running in the background with silent audio so new messages arrive as local notifications without any servers. Uses more battery.", "ecoGram работает в фоне благодаря беззвучному звуку и показывает новые сообщения локальными уведомлениями, без серверов. Расходует больше заряда.", "無音のオーディオでecoGramをバックグラウンドで動作させ、サーバーを使わずに新着メッセージをローカル通知で表示します。バッテリー消費が増えます。"),
        .savedTitle: ("Saved History", "Сохранённая история", "保存された履歴"),
        .savedEmpty: ("Nothing has been saved yet.", "Пока ничего не сохранено.", "まだ何も保存されていません。"),
        .savedUsage: ("Storage Used", "Занято", "使用容量"),
        .savedClearAll: ("Clear All History", "Очистить всю историю", "すべての履歴を削除"),
        .savedClearAllConfirm: ("Delete all saved messages and media?", "Удалить все сохранённые сообщения и медиа?", "保存されたすべてのメッセージとメディアを削除しますか？"),
        .savedClearChat: ("Clear This Chat", "Очистить этот чат", "このチャットを削除"),
        .savedClearChatConfirm: ("Delete saved messages of this chat?", "Удалить сохранённые сообщения этого чата?", "このチャットの保存されたメッセージを削除しますか？"),
        .savedDeleted: ("Deleted", "Удалено", "削除済み"),
        .savedEdited: ("Edited", "Изменено", "編集済み"),
        .savedWas: ("Before", "Было", "変更前"),
        .savedNow: ("After", "Стало", "変更後"),
        .savedCopy: ("Copy Text", "Скопировать текст", "テキストをコピー"),
        .savedOpenMedia: ("Open Media", "Открыть медиа", "メディアを開く"),
        .savedDelete: ("Delete", "Удалить", "削除"),
        .savedMediaNotSaved: ("not saved", "не сохранено", "未保存"),
        .mediaPhoto: ("Photo", "Фото", "写真"),
        .mediaVideo: ("Video", "Видео", "動画"),
        .mediaRoundVideo: ("Video Message", "Видеосообщение", "ビデオメッセージ"),
        .mediaVoice: ("Voice Message", "Голосовое сообщение", "ボイスメッセージ"),
        .mediaAudio: ("Audio", "Аудио", "オーディオ"),
        .mediaSticker: ("Sticker", "Стикер", "ステッカー"),
        .mediaAnimation: ("GIF", "GIF", "GIF"),
        .mediaFile: ("File", "Файл", "ファイル"),
        .mediaOther: ("Attachment", "Вложение", "添付ファイル"),
        .unitMegabytes: ("MB", "МБ", "MB"),
        .unitDays: ("days", "дней", "日"),
        .unitMonth: ("1 month", "1 месяц", "1か月"),
        .unitMonths: ("3 months", "3 месяца", "3か月"),
        .unitYear: ("1 year", "1 год", "1年")
    ]

    public let languageCode: String

    public init(languageCode: String) {
        if languageCode.hasPrefix("ru") || languageCode.hasPrefix("uk") || languageCode.hasPrefix("be") {
            self.languageCode = "ru"
        } else if languageCode.hasPrefix("ja") {
            self.languageCode = "ja"
        } else {
            self.languageCode = "en"
        }
    }

    public func get(_ key: Key) -> String {
        guard let entry = EcoStrings.table[key] else {
            return ""
        }
        switch self.languageCode {
        case "ru":
            return entry.ru
        case "ja":
            return entry.ja
        default:
            return entry.en
        }
    }

    public func mediaLimit(_ megabytes: Int) -> String {
        if megabytes <= 0 {
            return self.get(.historyMediaOff)
        }
        return "\(megabytes) \(self.get(.unitMegabytes))"
    }

    public func cleanupPeriod(_ days: Int) -> String {
        switch days {
        case ..<1:
            return self.get(.historyCleanupNever)
        case 30:
            return self.get(.unitMonth)
        case 90:
            return self.get(.unitMonths)
        case 365:
            return self.get(.unitYear)
        default:
            return "\(days) \(self.get(.unitDays))"
        }
    }
}
