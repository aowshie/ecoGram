import Foundation

public struct EcoStrings {
    public enum Key: CaseIterable {
        case settingsTitle
        case ayuTitle
        case ghostMode
        case ghostHideRead
        case ghostHideOnline
        case ghostHideTyping
        case ghostHideStoryViews
        case ghostKeepUnread
        case ghostFooter
        case ghostReadOnInteract
        case ghostEssentials
        case spyEssentials
        case ghostEnabledCount
        case historyTitle
        case exceptionsFooter
        case historySaveDeleted
        case historySaveSelfDestructing
        case historySaveEdited
        case historySaveBots
        case historyMediaLimit
        case historyMediaOff
        case historyCleanup
        case historyFooter
        case storageHeader
        case manageStorage
        case usageTitle
        case usageDescription
        case usageEmpty
        case usageMessages
        case usageMedia
        case usageDisappearing
        case usageEdits
        case usageCategoriesFooter
        case usageClearAll
        case usageClearTitle
        case usageClearText
        case usageKeptItem
        case usageCleanupFooter
        case usageMediaFooter
        case usageLaunchClear
        case usageLaunchFooter
        case badgesHeader
        case badgesShow
        case ayuBadgesFooter
        case badgesTitle
        case badgesTelegram
        case badgesTelegramLocked
        case badgesFooter
        case editHistory
        case editOriginal
        case editEdited
        case editCurrent
        case labelDeleted
        case labelExpired
        case labelOneView
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
        case appearanceTitle
        case spyTitle
        case spyScreenshots
        case spyScreenshotsFooter
        case protectedChats
        case protectedCopy
        case protectedSaving
        case protectedForward
        case forwardViaShot
        case protectedForwardFooter
        case hideProfileShortcuts
        case islandAvatarAnimation
        case islandAvatarFooter
        case badgeSupporterInfo
        case badgeOfficialInfo
        case badgeDeveloperInfo
        case badgeEarlyInfo
        case badgeChannelInfo
        case earlyBadgeTitle
        case earlyBadgeText
        case earlyBadgeOpen
        case shotPreferences
        case shotShowBackground
        case shotShowDate
        case shotShowReactions
        case shotShowEdited
        case shotOwnOnRight
        case shotAnonymize
        case shotAnonymizeFooter
        case shotAnonymous
        case shotHideBadges
        case shotShowTails
        case shotTheme
        case shotThemeApp
        case shotThemeDay
        case shotThemeNight
        case shotLimit
        case shotFromHere
        case shotCopy
        case shotCopied
        case labelTimer
        case actionShot
        case actionTag
        case actionSaveToCloud
        case shotSave
        case shotSaved
        case shotFailed
        case shotClose
    }

    private static let table: [Key: (en: String, ru: String, ja: String)] = [
        .settingsTitle: ("ecoGram", "ecoGram", "ecoGram"),
        .ayuTitle: ("AyuGram", "AyuGram", "AyuGram"),
        .ghostMode: ("Ghost Mode", "Режим призрака", "ゴーストモード"),
        .ghostHideRead: ("Don't Read Messages", "Не читать сообщения", "メッセージを既読にしない"),
        .ghostHideOnline: ("Don't Send Online", "Не отправлять онлайн", "オンラインを送信しない"),
        .ghostHideTyping: ("Don't Send Typing", "Не отправлять «печатает»", "入力中を送信しない"),
        .ghostHideStoryViews: ("Don't Read Stories", "Не читать истории", "ストーリーを既読にしない"),
        .ghostKeepUnread: ("Keep Unread Locally", "Не читать у себя", "自分側でも未読のままにする"),
        .ghostFooter: ("Others won't see that you are online, typing, reading their messages or viewing their stories. «Keep Unread Locally» leaves opened chats unread on this device too. «Read on Interact» marks a chat as read when you send a message to it.", "Собеседники не увидят, что вы в сети, печатаете, читаете их сообщения или смотрите истории. «Не читать у себя» оставляет открытые чаты непрочитанными и на этом устройстве. «Читать при ответе» отмечает чат прочитанным, когда вы отправляете в него сообщение.", "相手にオンライン、入力中、メッセージの既読、ストーリーの閲覧が表示されません。「自分側でも未読のままにする」をオンにすると、開いたチャットもこの端末で未読のままになります。「操作時に既読」はメッセージを送信したチャットを既読にします。"),
        .ghostReadOnInteract: ("Read on Interact", "Читать при ответе", "操作時に既読"),
        .ghostEssentials: ("GHOST ESSENTIALS", "ПРИЗРАК", "ゴースト"),
        .spyEssentials: ("SPY ESSENTIALS", "ШПИОН", "スパイ"),
        .ghostEnabledCount: ("%d of %d enabled", "Включено %d из %d", "%d / %d 有効"),
        .historyTitle: ("Message History", "История сообщений", "メッセージ履歴"),
        .exceptionsFooter: ("Online status is shared by all chats and can only be changed in Ghost Mode settings.", "Онлайн-статус общий для всех чатов, он меняется только в настройках режима призрака.", "オンライン状態はすべてのチャット共通で、ゴーストモードの設定でのみ変更できます。"),
        .historySaveDeleted: ("Save Deleted Messages", "Сохранять удалённые", "削除されたメッセージを保存"),
        .historySaveSelfDestructing: ("Save Self-Destructing Messages", "Сохранять самоудаляющиеся", "自動削除メッセージを保存"),
        .historySaveEdited: ("Save Edit History", "Сохранять историю изменений", "編集履歴を保存"),
        .historySaveBots: ("Include Chats with Bots", "Включая чаты с ботами", "ボットとのチャットも含める"),
        .historyMediaLimit: ("Keep Media up To", "Сохранять медиа до", "メディアの保存上限"),
        .historyMediaOff: ("Don't Keep", "Не сохранять", "保存しない"),
        .historyCleanup: ("Delete Older Than", "Удалять старше", "古い履歴を削除"),
        .historyFooter: ("Deleted and self-destructing messages stay in the chat, slightly faded and marked as deleted or expired. One-time media arrives under a spoiler and can be opened any number of times. Hold an edited message to see its previous versions. Everything is kept only on this device.", "Удалённые и самоудаляющиеся сообщения остаются в чате: они полупрозрачные и подписаны «удалено» или «истекло». Одноразовые фото и видео приходят под спойлером и открываются сколько угодно раз. Прошлые версии изменённого сообщения видны в его меню. Всё хранится только на этом устройстве.", "削除・自動削除されたメッセージは半透明で「削除済み」「期限切れ」と表示されたままチャットに残ります。1回表示のメディアはスポイラー付きで届き、何度でも開けます。編集されたメッセージを長押しすると以前の版を確認できます。すべてこの端末にのみ保存されます。"),
        .storageHeader: ("STORAGE", "ПАМЯТЬ", "ストレージ"),
        .manageStorage: ("Manage Storage", "Управление памятью", "ストレージを管理"),
        .usageTitle: ("ecoGram Usage", "Память ecoGram", "ecoGramの使用量"),
        .usageDescription: ("ecoGram uses **%@%** of your free disk space.", "ecoGram занимает **%@%** свободного места на устройстве.", "ecoGramは空き容量の**%@%**を使用しています。"),
        .usageEmpty: ("Deleted and edited messages saved by ecoGram will appear here.", "Здесь появятся удалённые и изменённые сообщения, которые сохранит ecoGram.", "ecoGramが保存した削除済み・編集済みメッセージがここに表示されます。"),
        .usageMessages: ("Deleted Messages", "Удалённые сообщения", "削除されたメッセージ"),
        .usageMedia: ("Media of Deleted", "Медиа удалённых", "削除されたメディア"),
        .usageDisappearing: ("Disappearing Media", "Исчезающие медиа", "消えるメディア"),
        .usageEdits: ("Edit History", "История правок", "編集履歴"),
        .usageCategoriesFooter: ("Clearing messages also clears their media. Cleared data can't be restored.", "Вместе с сообщениями очищаются и их медиа. Очищенное восстановить нельзя.", "メッセージを消去すると、そのメディアも消去されます。消去したデータは復元できません。"),
        .usageClearAll: ("Clear All", "Очистить всё", "すべて消去"),
        .usageClearTitle: ("Clear Saved Data?", "Очистить сохранённое?", "保存データを消去しますか？"),
        .usageClearText: ("The selected deleted messages, media and edits will be removed from this device for good.", "Выбранные удалённые сообщения, медиа и правки исчезнут с устройства навсегда.", "選択した削除済みメッセージ、メディア、編集履歴はこの端末から完全に削除されます。"),
        .usageKeptItem: ("Deleted and Edited", "Удалённые и изменённые", "削除済み・編集済み"),
        .usageCleanupFooter: ("Saved messages, media and edits older than this are removed automatically.", "Сохранённые сообщения, медиа и правки старше этого срока удаляются автоматически.", "この期間より古い保存済みメッセージ、メディア、編集履歴は自動的に削除されます。"),
        .usageMediaFooter: ("Media larger than this isn't kept when a message is deleted.", "Медиа больше этого размера не сохраняются при удалении сообщения.", "メッセージが削除されたとき、これより大きいメディアは保存されません。"),
        .usageLaunchClear: ("Clear on Launch", "Очищать при запуске", "起動時に消去"),
        .usageLaunchFooter: ("Each time ecoGram is fully closed and opened again, it clears everything it saved: deleted messages, their media, disappearing media and edit history.", "Каждый раз, когда ecoGram полностью закрывают и открывают снова, он очищает всё сохранённое: удалённые сообщения, их медиа, исчезающие медиа и историю правок.", "ecoGramを完全に終了して再び開くたびに、保存したすべてのデータ（削除されたメッセージ、そのメディア、消えるメディア、編集履歴）を消去します。"),
        .badgesHeader: ("BADGES", "ЗНАЧКИ", "バッジ"),
        .badgesShow: ("AyuGram Badges", "Значки AyuGram", "AyuGramバッジ"),
        .ayuBadgesFooter: ("Shows the badges of AyuGram developers and supporters next to their names. Badge order and ecoGram badges are in [ecoGram Settings].", "Показывает значки разработчиков и поддержавших AyuGram рядом с именем. Порядок значков и значки ecoGram — в [настройках ecoGram].", "AyuGramの開発者と支援者のバッジを名前の横に表示します。バッジの順番とecoGramのバッジは[ecoGramの設定]で変更できます。"),
        .badgesTitle: ("Badges", "Значки", "バッジ"),
        .badgesTelegram: ("Telegram", "Telegram", "Telegram"),
        .badgesTelegramLocked: ("Telegram badges can't be hidden, but you can move them.", "Значки Telegram нельзя скрыть, но их можно передвинуть.", "Telegramのバッジは非表示にできませんが、移動はできます。"),
        .badgesFooter: ("Choose whose badges to show and drag them to set their order next to names. The public lists come from the AyuGram server (or exteraGram's as a fallback) and api.ecogram.cc. To give out the early user badge, ecoGram sends your Telegram ID to api.ecogram.cc once.", "Отметьте, чьи значки показывать, и перетащите их, чтобы задать порядок рядом с именем. Публичные списки загружаются с сервера AyuGram (запасной вариант — сервер exteraGram) и api.ecogram.cc. Чтобы выдать значок раннего пользователя, ecoGram один раз отправляет ваш Telegram ID на api.ecogram.cc.", "表示するバッジを選び、ドラッグして名前の横の順番を決めます。公開リストはAyuGramのサーバー（予備としてexteraGramのサーバー）とapi.ecogram.ccから取得します。初期ユーザーバッジを付与するため、ecoGramはTelegram IDを一度だけapi.ecogram.ccに送信します。"),
        .editHistory: ("Edit History", "История изменений", "編集履歴"),
        .editOriginal: ("Original", "Исходное", "元の内容"),
        .editEdited: ("Edited", "Изменено", "編集"),
        .editCurrent: ("Current", "Сейчас", "現在"),
        .labelDeleted: ("deleted", "удалено", "削除済み"),
        .labelExpired: ("expired", "истекло", "期限切れ"),
        .labelOneView: ("one view", "одноразовое", "1回表示"),
        .notificationsHeader: ("NOTIFICATIONS", "УВЕДОМЛЕНИЯ", "通知"),
        .notificationsBackground: ("Local Notifications", "Локальные уведомления", "ローカル通知"),
        .notificationSettings: ("Notification Settings", "Настройки уведомлений", "通知設定"),
        .notificationsFooter: ("Keeps ecoGram running in the background with silent audio so new messages arrive as local notifications without any servers.", "ecoGram работает в фоне благодаря беззвучному звуку и показывает новые сообщения локальными уведомлениями, без серверов.", "無音のオーディオでecoGramをバックグラウンドで動作させ、サーバーを使わずに新着メッセージをローカル通知で表示します。"),
        .chatHeader: ("CHAT", "ЧАТ", "チャット"),
        .selectionPanel: ("Selection Bar", "Панель выделения", "選択バー"),
        .contextMenu: ("Message Menu", "Меню сообщения", "メッセージメニュー"),
        .chatFooter: ("Choose which buttons are shown and in what order.", "Выберите, какие кнопки показывать и в каком порядке.", "表示するボタンと順番を選べます。"),
        .selectionFooter: ("Buttons shown at the bottom while messages are selected. Check up to 5 and drag to reorder.", "Кнопки внизу экрана при выделении сообщений. Отметьте до 5 кнопок и перетащите, чтобы изменить порядок.", "メッセージ選択中に下部に表示されるボタンです。最大5つまでチェックでき、ドラッグで並べ替えます。"),
        .selectionLimit: ("You can enable up to 5 buttons", "Можно включить не больше 5 кнопок", "有効にできるボタンは5つまでです"),
        .contextFooter: ("Items shown when you hold a message. Check the ones you need and drag to reorder. Unchecked items are hidden, and the switches match the Swiftgram section.", "Пункты, которые появляются при удержании сообщения. Отметьте нужные и перетащите, чтобы изменить порядок. Неотмеченные пункты скрыты, переключатели совпадают с разделом Swiftgram.", "メッセージを長押ししたときに表示される項目です。必要なものにチェックを入れ、ドラッグで並べ替えます。チェックしない項目は非表示になり、Swiftgramの設定と連動します。"),
        .appearanceHeader: ("APPEARANCE", "ОФОРМЛЕНИЕ", "外観"),
        .appearanceTitle: ("Appearance", "Оформление", "外観"),
        .spyTitle: ("Spy Essentials", "Шпион", "スパイ"),
        .spyScreenshots: ("Screenshots", "Скриншоты", "スクリーンショット"),
        .spyScreenshotsFooter: ("Works in chats and channels that restrict saving content.", "Работает в чатах и каналах с запретом копирования.", "コンテンツの保存が制限されたチャットやチャンネルで動作します。"),
        .protectedChats: ("Protected Chats", "Защищённые чаты", "保護されたチャット"),
        .protectedCopy: ("Copy Text", "Копирование текста", "テキストのコピー"),
        .protectedSaving: ("Save Media", "Сохранение медиа", "メディアの保存"),
        .protectedForward: ("Forward via Shot", "Пересылка через Shot", "Shotで転送"),
        .forwardViaShot: ("Forward via Shot", "Переслать через Shot", "Shotで転送"),
        .protectedForwardFooter: ("Sends the messages as a Shot image to the chat you choose. Requires Screenshots.", "Отправляет сообщения картинкой Shot в выбранный чат. Работает при включённых скриншотах.", "メッセージをShot画像として選んだチャットに送信します。スクリーンショットをオンにする必要があります。"),
        .hideProfileShortcuts: ("Hide Profile Suggestions", "Скрыть предложения профиля", "プロフィールの提案を隠す"),
        .islandAvatarAnimation: ("Dynamic Island Effect", "Эффект Dynamic Island", "Dynamic Island効果"),
        .islandAvatarFooter: ("On iPhones without the Dynamic Island, the profile photo flows into the top of the screen like a drop as you scroll.", "На iPhone без Dynamic Island аватарка при прокрутке профиля втягивается в верх экрана, как капля.", "Dynamic IslandのないiPhoneで、スクロールするとプロフィール写真が水滴のように画面上部へ吸い込まれます。"),
        .badgeSupporterInfo: ("**%@** supported the development of exteraGram or AyuGram and received a unique badge.", "За поддержку разработки exteraGram или AyuGram **%@** получает уникальный значок.", "**%@**はexteraGramまたはAyuGramの開発を支援し、特別なバッジを受け取りました。"),
        .badgeOfficialInfo: ("**%@** is the official resource of exteraGram or AyuGram.", "**%@** — официальный ресурс exteraGram или AyuGram.", "**%@**はexteraGramまたはAyuGramの公式リソースです。"),
        .badgeDeveloperInfo: ("**%@** is the developer of ecoGram.", "**%@** — разработчик ecoGram.", "**%@**はecoGramの開発者です。"),
        .badgeEarlyInfo: ("**%@** is one of the first ecoGram users.", "**%@** — один из первых пользователей ecoGram.", "**%@**はecoGramの初期ユーザーの一人です。"),
        .badgeChannelInfo: ("**%@** is the official ecoGram channel.", "**%@** — официальный канал ecoGram.", "**%@**はecoGramの公式チャンネルです。"),
        .earlyBadgeTitle: ("Early User Badge", "Значок раннего пользователя", "初期ユーザーバッジ"),
        .earlyBadgeText: ("You are one of the first ecoGram users. The badge is now next to your name, and everyone with ecoGram can see it.", "Вы один из первых пользователей ecoGram. Значок уже стоит рядом с вашим именем, его видят все, у кого установлен ecoGram.", "あなたはecoGramの初期ユーザーの一人です。バッジが名前の横に表示され、ecoGramを使っている全員に見えます。"),
        .earlyBadgeOpen: ("Badge Settings", "Перейти", "バッジ設定"),
        .shotPreferences: ("Preferences", "Настройки", "設定"),
        .shotShowBackground: ("Show Background", "Показывать фон", "背景を表示"),
        .shotShowDate: ("Show Date", "Показывать дату", "日付を表示"),
        .shotShowReactions: ("Show Reactions", "Показывать реакции", "リアクションを表示"),
        .shotShowEdited: ("Show “Edited”", "Показывать «изменено»", "「編集済み」を表示"),
        .shotOwnOnRight: ("My Messages on the Right", "Мои сообщения справа", "自分のメッセージを右側に"),
        .shotAnonymize: ("Hide Names and Photos", "Скрыть имена и фото", "名前と写真を隠す"),
        .shotAnonymizeFooter: ("Everyone is shown as Anonymous 1, 2, 3 without profile photos.", "Все участники показываются как Аноним 1, 2, 3 без фото профиля.", "全員がプロフィール写真なしで匿名 1、2、3 と表示されます。"),
        .shotAnonymous: ("Anonymous", "Аноним", "匿名"),
        .shotHideBadges: ("Hide Badges", "Скрыть значки", "バッジを隠す"),
        .shotShowTails: ("Message Tails", "Хвосты у сообщений", "吹き出しのしっぽ"),
        .shotTheme: ("Theme", "Тема", "テーマ"),
        .shotThemeApp: ("Same as App", "Как в приложении", "アプリと同じ"),
        .shotThemeDay: ("Light", "Светлая", "ライト"),
        .shotThemeNight: ("Dark", "Тёмная", "ダーク"),
        .shotLimit: ("A shot fits up to %d messages, so only the first ones are included.", "В Shot помещается до %d сообщений, взяты только первые.", "Shotに入るのは最大%d件のため、最初のメッセージのみ含めました。"),
        .shotFromHere: ("Shot from Here", "Shot отсюда", "ここからShot"),
        .shotCopy: ("Copy", "Скопировать", "コピー"),
        .shotCopied: ("Copied to clipboard", "Скопировано в буфер обмена", "クリップボードにコピーしました"),
        .labelTimer: ("timer", "таймер", "タイマー"),
        .actionShot: ("Shot", "Shot", "Shot"),
        .actionTag: ("Tag", "Тег", "タグ"),
        .actionSaveToCloud: ("Save to Saved Messages", "В Избранное", "保存済みメッセージに保存"),
        .shotSave: ("Save", "Сохранить", "保存"),
        .shotSaved: ("Saved to Photos", "Сохранено в Фото", "写真に保存しました"),
        .shotFailed: ("Couldn't create the shot", "Не удалось сделать снимок", "スクリーンショットを作成できませんでした"),
        .shotClose: ("Close", "Закрыть", "閉じる")
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

    public func format(_ key: Key, _ value: String) -> String {
        return self.get(key).replacingOccurrences(of: "%@", with: value)
    }

    public func selfDestructLabel(timeout: Int32) -> String {
        let units: (second: String, minute: String)
        switch self.languageCode {
        case "ru":
            units = ("с", "м")
        case "ja":
            units = ("秒", "分")
        default:
            units = ("s", "m")
        }
        let value = timeout >= 60 && timeout % 60 == 0 ? "\(timeout / 60)\(units.minute)" : "\(timeout)\(units.second)"
        let separator = self.languageCode == "ja" ? "" : " "
        return "\(self.get(.labelTimer))\(separator)\(value)"
    }
}
