<p align="center">
  <img src="Branding/Icon/readme.svg" width="128" height="128" alt="ecoGram">
</p>

<h1 align="center">ecoGram</h1>

<p align="center">
  Telegram for iOS based on <a href="https://github.com/Swiftgram/Telegram-iOS">Swiftgram</a> with <a href="https://github.com/AyuGram">AyuGram</a> features
</p>

<p align="center">
  <a href="../../releases">Download</a> · <a href="#install">Install</a> · <a href="#build">Build</a>
</p>

---

## Features

### Swiftgram

- Based on

### AyuGram

- Ghost mode with per-chat exceptions
- Read on interact
- Deleted message history
- One-time photos and videos
- Edit history
- AyuGram badges
- Shot

### ecoGram

- Local notifications
- Custom selection bar
- Custom message menu
- Avatar in the Settings tab
- Dynamic Island profile effect on any iPhone
- Hidden profile shortcuts

## Privacy

No own servers, no analytics. History stays on the device.

## Install

IPA from [releases](../../releases), signed with SideStore, AltStore, Sideloadly, Feather or ESign.

## Build

GitHub Actions: `Build` workflow, `TELEGRAM_API_ID` and `TELEGRAM_API_HASH` secrets.

Locally, on a Mac:

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
