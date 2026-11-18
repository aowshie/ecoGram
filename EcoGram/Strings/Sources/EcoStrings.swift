import Foundation

public struct EcoStrings {
    public enum Key: CaseIterable {
        case settingsTitle
        case ayuTitle
        case ghostHeader
        case ghostMode
        case ghostHideRead
        case ghostHideOnline
        case ghostHideTyping
        case ghostHideStoryViews
        case ghostFooter
        case historyHeader
        case historySaveDeleted
        case historySaveSelfDestructing
        case historySaveEdited
        case historySaveBots
        case historyMediaLimit
        case historyMediaOff
        case historyCleanup
        case historyCleanupNever
        case historyClearDeleted
        case historyClearDeletedConfirm
        case historyFooter
        case badgesHeader
        case badgesShow
        case badgesFooter
        case editHistory
        case editOriginal
        case editEdited
        case editCurrent
        case notificationsHeader
        case notificationsBackground
        case notificationSettings
        case notificationsFooter
        case chatHeader
        case selectionPanel
        case contextMenu
        case chatFooter
        case selectionFooter
        case selectionLimit
        case contextFooter
        case appearanceHeader
        case avatarInTabBar
        case appearanceFooter
        case actionShot
        case actionTag
        case actionSaveToCloud
        case shotSave
        case shotShare
        case shotSaved
        case shotFailed
        case shotClose
        case unitMegabytes
        case unitDays
        case unitMonth
        case unitMonths
        case unitYear
    }

    private static let table: [Key: (en: String, ru: String, ja: String)] = [
        .settingsTitle: ("ecoGram", "ecoGram", "ecoGram"),
        .ayuTitle: ("AyuGram", "AyuGram", "AyuGram"),
        .ghostHeader: ("GHOST MODE", "РЕЖИМ ПРИЗРАКА", "ゴーストモード"),
        .ghostMode: ("Ghost Mode", "Режим призрака", "ゴーストモード"),
        .ghostHideRead: ("Don't Send Read Receipts", "Не отправлять прочтение", "既読を送信しない"),
        .ghostHideOnline: ("Don't Send Online Status", "Не показывать онлайн", "オンライン状態を送信しない"),
        .ghostHideTyping: ("Don't Send Typing Status", "Не показывать «печатает»", "入力中を送信しない"),
        .ghostHideStoryViews: ("Don't Mark Stories as Viewed", "Не отмечать истории просмотренными", "ストーリーを既読にしない"),
        .ghostFooter: ("Others won't see that you are online, typing or reading their messages.", "Собеседники не увидят, что вы в сети, печатаете или прочитали их сообщения.", "相手にオンライン、入力中、既読であることが表示されません。"),
        .historyHeader: ("MESSAGE HISTORY", "ИСТОРИЯ СООБЩЕНИЙ", "メッセージ履歴"),
        .historySaveDeleted: ("Save Deleted Messages", "Сохранять удалённые", "削除されたメッセージを保存"),
        .historySaveSelfDestructing: ("Save Self-Destructing Messages", "Сохранять самоудаляющиеся", "自動削除メッセージを保存"),
        .historySaveEdited: ("Save Edit History", "Сохранять историю изменений", "編集履歴を保存"),
        .historySaveBots: ("Include Chats with Bots", "Включая чаты с ботами", "ボットとのチャットも含める"),
        .historyMediaLimit: ("Keep Media up To", "Сохранять медиа до", "メディアの保存上限"),
        .historyMediaOff: ("Don't Keep", "Не сохранять", "保存しない"),
        .historyCleanup: ("Delete Older Than", "Удалять старше", "古い履歴を削除"),
        .historyCleanupNever: ("Never", "Никогда", "削除しない"),
        .historyClearDeleted: ("Clear Deleted Messages", "Очистить удалённые сообщения", "削除されたメッセージを消去"),
        .historyClearDeletedConfirm: ("Remove all saved deleted messages from your chats?", "Убрать все сохранённые удалённые сообщения из чатов?", "保存された削除済みメッセージをすべてチャットから消去しますか？"),
        .historyFooter: ("Deleted and self-destructing messages stay in the chat, slightly faded and marked with a trash icon. Hold an edited message to see its previous versions. Everything is kept only on this device.", "Удалённые и самоудаляющиеся сообщения остаются в чате: они полупрозрачные и отмечены значком корзины. Прошлые версии изменённого сообщения видны в его меню. Всё хранится только на этом устройстве.", "削除・自動削除されたメッセージは半透明のままゴミ箱アイコン付きでチャットに残ります。編集されたメッセージを長押しすると以前の版を確認できます。すべてこの端末にのみ保存されます。"),
        .badgesHeader: ("BADGES", "ЗНАЧКИ", "バッジ"),
        .badgesShow: ("AyuGram Badges", "Значки AyuGram", "AyuGramバッジ"),
        .badgesFooter: ("Shows the badges of AyuGram developers and supporters next to their names. The public list is downloaded from the AyuGram server, nothing is sent.", "Показывает значки разработчиков и поддержавших AyuGram рядом с именем. Публичный список загружается с сервера AyuGram, от вас ничего не отправляется.", "AyuGramの開発者と支援者のバッジを名前の横に表示します。公開リストをAyuGramのサーバーから取得し、こちらからは何も送信しません。"),
        .editHistory: ("Edit History", "История изменений", "編集履歴"),
        .editOriginal: ("Original", "Исходное", "元の内容"),
        .editEdited: ("Edited", "Изменено", "編集"),
        .editCurrent: ("Current", "Сейчас", "現在"),
        .notificationsHeader: ("NOTIFICATIONS", "УВЕДОМЛЕНИЯ", "通知"),
        .notificationsBackground: ("Local Notifications", "Локальные уведомления", "ローカル通知"),
        .notificationSettings: ("Notification Settings", "Настройки уведомлений", "通知設定"),
        .notificationsFooter: ("Keeps ecoGram running in the background with silent audio so new messages arrive as local notifications without any servers. Uses more battery.", "ecoGram работает в фоне благодаря беззвучному звуку и показывает новые сообщения локальными уведомлениями, без серверов. Расходует больше заряда.", "無音のオーディオでecoGramをバックグラウンドで動作させ、サーバーを使わずに新着メッセージをローカル通知で表示します。バッテリー消費が増えます。"),
        .chatHeader: ("CHAT", "ЧАТ", "チャット"),
        .selectionPanel: ("Selection Bar", "Панель выделения", "選択バー"),
        .contextMenu: ("Message Menu", "Меню сообщения", "メッセージメニュー"),
        .chatFooter: ("Choose which buttons are shown and in what order.", "Выберите, какие кнопки показывать и в каком порядке.", "表示するボタンと順番を選べます。"),
        .selectionFooter: ("Buttons shown at the bottom while messages are selected. Check up to 6 and drag to reorder.", "Кнопки внизу экрана при выделении сообщений. Отметьте до 6 кнопок и перетащите, чтобы изменить порядок.", "メッセージ選択中に下部に表示されるボタンです。最大6つまでチェックでき、ドラッグで並べ替えます。"),
        .selectionLimit: ("You can enable up to 6 buttons", "Можно включить не больше 6 кнопок", "有効にできるボタンは6つまでです"),
        .contextFooter: ("Items shown when you hold a message. Check the ones you need and drag to reorder. Hidden items stay in the Swiftgram submenu, and the switches match the Swiftgram section.", "Пункты, которые появляются при удержании сообщения. Отметьте нужные и перетащите, чтобы изменить порядок. Скрытые пункты остаются в подменю Swiftgram, переключатели совпадают с разделом Swiftgram.", "メッセージを長押ししたときに表示される項目です。必要なものにチェックを入れ、ドラッグで並べ替えます。非表示の項目はSwiftgramのサブメニューに残り、Swiftgramの設定と連動します。"),
        .appearanceHeader: ("APPEARANCE", "ОФОРМЛЕНИЕ", "外観"),
        .avatarInTabBar: ("Avatar Instead of Settings Icon", "Аватарка вместо шестерёнки", "設定アイコンの代わりにアバター"),
        .appearanceFooter: ("Shows your profile photo on the Settings tab at the bottom of the screen.", "Во вкладке «Настройки» внизу экрана показывается ваша аватарка.", "画面下部の設定タブにプロフィール写真を表示します。"),
        .actionShot: ("Shot", "Shot", "Shot"),
        .actionTag: ("Tag", "Тег", "タグ"),
        .actionSaveToCloud: ("Save to Saved Messages", "В Избранное", "保存済みメッセージに保存"),
        .shotSave: ("Save", "Сохранить", "保存"),
        .shotShare: ("Share", "Поделиться", "共有"),
        .shotSaved: ("Saved to Photos", "Сохранено в Фото", "写真に保存しました"),
        .shotFailed: ("Couldn't create the shot", "Не удалось сделать снимок", "スクリーンショットを作成できませんでした"),
        .shotClose: ("Close", "Закрыть", "閉じる"),
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
