# ecoGram

Telegram-клиент для iOS на базе [Swiftgram](https://github.com/Swiftgram/Telegram-iOS) с возможностями [AyuGram](https://github.com/AyuGram).

## Структура

| Путь | Назначение |
| --- | --- |
| `EcoGram/Ayu/` | Возможности AyuGram: режим призрака, история сообщений, значки, Shot |
| `EcoGram/Settings/` | Раздел ecoGram в настройках |
| `EcoGram/Preferences/` | Настройки ecoGram: уведомления, панель выделения, меню, оформление |
| `EcoGram/ContextMenu/` | Порядок пунктов меню сообщения |
| `EcoGram/Notifications/` | Локальные уведомления в фоне |
| `EcoGram/Strings/` | Тексты на русском, английском и японском |
| `Patches/` | Точечные правки исходников Swiftgram, по одному коммиту на патч |
| `Branding/` | Имя, bundle ID и иконки |
| `Tools/ecogram/` | Утилита для синхронизации, патчей и сборки |
| `upstream.json` | Закреплённый коммит Swiftgram |

## Работа с патчами

```bash
python -m Tools.ecogram sync
```

Скачивает закреплённый Swiftgram в `.work/swiftgram` и применяет патчи коммитами. После правок и коммитов в этом дереве:

```bash
python -m Tools.ecogram export
```

## Обновление Swiftgram

Workflow `Upstream` каждый день закрепляет свежий коммит Swiftgram. Если патчи применяются чисто, он коммитит обновление, иначе открывает issue. Вручную:

```bash
python -m Tools.ecogram bump
```

## Сборка

Workflow `Build` собирает неподписанный IPA на macOS-раннере и публикует его в релизах. Нужны секреты `TELEGRAM_API_ID` и `TELEGRAM_API_HASH`. На своём Mac с нужной версией Xcode:

```bash
python -m Tools.ecogram prepare
```

```bash
TELEGRAM_API_ID=… TELEGRAM_API_HASH=… python -m Tools.ecogram build
```

IPA перед установкой подписывается через SideStore, AltStore, Sideloadly, Feather или ESign.

## Лицензия

GPL-2.0, как у Telegram для iOS и Swiftgram. Иконки значков и логотип AyuGram взяты из AyuGram Desktop (GPL-3.0).
