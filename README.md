<p align="center">
  <img src="Branding/Icon/readme.svg" width="128" height="128" alt="ecoGram">
</p>

<h1 align="center">ecoGram</h1>

<p align="center">
  Telegram для iOS на основе <a href="https://github.com/Swiftgram/Telegram-iOS">Swiftgram</a> с возможностями <a href="https://github.com/AyuGram">AyuGram</a>
</p>

<p align="center">
  <a href="../../releases">Скачать</a> · <a href="#установка">Установка</a> · <a href="#сборка">Сборка</a>
</p>

---

## Возможности

### AyuGram

- **Режим призрака** — без прочтений, онлайна, «печатает» и просмотров историй. Чаты можно оставлять непрочитанными и у себя.
- **Удалённые сообщения** остаются в чате с пометкой «удалено», сообщения по таймеру — с пометкой «истекло».
- **Одноразовые фото и видео** приходят под спойлером и открываются сколько угодно раз.
- **История изменений** — прошлые версии сообщения в его меню.
- **Значки** разработчиков и поддержавших AyuGram рядом с именем.
- **Shot** — картинка из выбранных сообщений в цветах вашей темы.

### ecoGram

- **Уведомления без серверов** — приложение работает в фоне и показывает локальные уведомления.
- **Панель выделения** — свои кнопки и их порядок.
- **Меню сообщения** — свои пункты и порядок, общие с настройками Swiftgram.
- **Аватарка** вместо шестерёнки во вкладке настроек.
- **Без лишнего** — можно скрыть кнопки профиля в настройках.

И всё, что есть в Swiftgram.

## Приватность

ecoGram не добавляет своих серверов и не собирает статистику. История удалённых и изменённых сообщений хранится только на устройстве. Единственный внешний запрос ecoGram — публичный список значков AyuGram, он отключается в настройках.

## Установка

Скачайте IPA из [релизов](../../releases) и подпишите его через SideStore, AltStore, Sideloadly, Feather или ESign.

## Сборка

IPA собирается в GitHub Actions: workflow `Build`, секреты `TELEGRAM_API_ID` и `TELEGRAM_API_HASH`.

На Mac с версией Xcode из `versions.json` Swiftgram:

```bash
python -m Tools.ecogram prepare
```

```bash
TELEGRAM_API_ID=… TELEGRAM_API_HASH=… python -m Tools.ecogram build
```

Swiftgram обновляется сам: workflow `Upstream` каждый день проверяет новый коммит и применяет патчи. Если патч не встаёт, открывается issue.

## Структура

| Путь | Что там |
| --- | --- |
| `EcoGram/Ayu/` | Возможности AyuGram |
| `EcoGram/Settings/` | Раздел ecoGram в настройках |
| `EcoGram/Preferences/` | Настройки ecoGram |
| `EcoGram/ContextMenu/` | Порядок пунктов меню сообщения |
| `EcoGram/Notifications/` | Локальные уведомления |
| `EcoGram/Strings/` | Тексты на русском, английском и японском |
| `Patches/` | Правки исходников Swiftgram |
| `Branding/` | Название, bundle ID и иконки |
| `Tools/ecogram/` | Синхронизация, патчи и сборка |

Работа с патчами:

```bash
python -m Tools.ecogram sync
```

```bash
python -m Tools.ecogram export
```

## Благодарности

[Telegram](https://github.com/TelegramMessenger/Telegram-iOS), [Swiftgram](https://github.com/Swiftgram/Telegram-iOS), [AyuGram](https://github.com/AyuGram/AyuGramDesktop).

## Лицензия

GPL-2.0, как у Telegram для iOS и Swiftgram. Иконки значков и логотип AyuGram взяты из AyuGram Desktop (GPL-3.0).
