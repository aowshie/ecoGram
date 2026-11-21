<p align="center">
  <img src="Branding/Icon/readme.svg" width="128" height="128" alt="ecoGram">
</p>

<h1 align="center">ecoGram</h1>

<p align="center">
  Telegram for iOS based on <a href="https://github.com/Swiftgram/Telegram-iOS">Swiftgram</a> with <a href="https://github.com/AyuGram">AyuGram</a> features
</p>

<p align="center">
  <a href="../../releases">Download</a> · <a href="https://t.me/ecoGramiOS">Channel</a> · <a href="#install">Install</a> · <a href="#build">Build</a>
</p>

---

## Features

### Swiftgram

- Based on

### AyuGram

- Ghost mode with per-chat exceptions for each option
- Read on interact: replies and reactions
- Deleted message history
- One-time photos and videos
- Edit history
- AyuGram badges
- Shot

### ecoGram

- Local notifications
- Custom selection bar
- Custom message menu
- Dynamic Island profile effect on any iPhone
- Hidden profile shortcuts
- Screenshots in chats that restrict saving content
- ecoGram badges: developer, official channel and the first 30 users
- Badge order and visibility for Telegram, AyuGram and ecoGram badges

## Privacy

No analytics. History stays on the device. The only ecoGram server is `api.ecogram.cc`: it serves the public badge list, and the app sends it your Telegram ID to hand out the early user badge until the server answers. Turning off ecoGram badges stops both. AyuGram badges are downloaded from the AyuGram server, or exteraGram's as a fallback; turning them off stops that too.

## Install

IPA from [releases](../../releases), signed with SideStore, AltStore, Sideloadly, Feather or ESign.

## Build

GitHub Actions: `Build` workflow, `TELEGRAM_API_ID` and `TELEGRAM_API_HASH` secrets.

Locally, on a Mac with Python 3.11 or newer, `librsvg` (`brew install librsvg`) and the Xcode version from the pinned Swiftgram `versions.json` selected:

```bash
python -m Tools.ecogram prepare
```

```bash
TELEGRAM_API_ID=… TELEGRAM_API_HASH=… python -m Tools.ecogram build
```

Swiftgram updates are pulled automatically by the `Upstream` workflow.

## Structure

| Path | |
| --- | --- |
| `EcoGram/Ayu/` | AyuGram |
| `EcoGram/Settings/` | ecoGram section |
| `EcoGram/Preferences/` | Preferences |
| `EcoGram/ContextMenu/` | Message menu |
| `EcoGram/Notifications/` | Notifications |
| `EcoGram/Badges/` | ecoGram badges |
| `EcoGram/Strings/` | Strings ru, en, ja |
| `Patches/` | Swiftgram patches |
| `Branding/` | Branding |
| `Tools/ecogram/` | Tools |

Patches:

```bash
python -m Tools.ecogram sync
```

```bash
python -m Tools.ecogram export
```

## Credits

[Telegram](https://github.com/TelegramMessenger/Telegram-iOS), [Swiftgram](https://github.com/Swiftgram/Telegram-iOS), [AyuGram](https://github.com/AyuGram/AyuGramDesktop).

## License

GPL-2.0. AyuGram badges and logo are from AyuGram Desktop (GPL-3.0).
