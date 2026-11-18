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

- Режим призрака
- Сохранение удалённых сообщений
- Одноразовые фото и видео
- История изменений
- Значки AyuGram
- Shot

### ecoGram

- Локальные уведомления
- Настройка панели выделения
- Настройка меню сообщения
- Аватарка во вкладке настроек
- Скрытие кнопок профиля

## Приватность

Без своих серверов и статистики. История хранится только на устройстве.

## Установка

IPA из [релизов](../../releases), подпись через SideStore, AltStore, Sideloadly, Feather или ESign.

## Сборка

GitHub Actions: workflow `Build`, секреты `TELEGRAM_API_ID` и `TELEGRAM_API_HASH`.

Локально, на Mac:

```bash
python -m Tools.ecogram prepare
```

```bash
TELEGRAM_API_ID=… TELEGRAM_API_HASH=… python -m Tools.ecogram build
```

Swiftgram подтягивается автоматически workflow `Upstream`.

## Структура

| Путь | |
| --- | --- |
| `EcoGram/Ayu/` | AyuGram |
| `EcoGram/Settings/` | Раздел ecoGram |
| `EcoGram/Preferences/` | Настройки |
| `EcoGram/ContextMenu/` | Меню сообщения |
| `EcoGram/Notifications/` | Уведомления |
| `EcoGram/Strings/` | Тексты ru, en, ja |
| `Patches/` | Патчи Swiftgram |
| `Branding/` | Брендинг |
| `Tools/ecogram/` | Инструменты |

Патчи:

```bash
python -m Tools.ecogram sync
```

```bash
python -m Tools.ecogram export
```

## Credits

[Telegram](https://github.com/TelegramMessenger/Telegram-iOS), [Swiftgram](https://github.com/Swiftgram/Telegram-iOS), [AyuGram](https://github.com/AyuGram/AyuGramDesktop).

## Лицензия

GPL-2.0. Значки и логотип AyuGram — из AyuGram Desktop (GPL-3.0).
