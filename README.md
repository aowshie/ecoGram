<p align="center">
  <img src="Branding/Icon/readme.svg" width="128" height="128" alt="ecoGram">
</p>

<h1 align="center">ecoGram</h1>

<p align="center">
  Telegram for iOS based on <a href="https://github.com/Swiftgram/Telegram-iOS">Swiftgram</a>, with <a href="https://github.com/AyuGram">AyuGram</a> features
</p>

<p align="center">
  <a href="../../releases">Download</a> · <a href="https://t.me/ecoGramiOS">Channel</a> · <a href="#install">Install</a> · <a href="#build">Build</a>
</p>

---

## Features

### Ghost essentials

- Don't send read receipts, online status, typing or story views, each on its own
- Per-chat exceptions for every option
- Keep chats unread on this device too
- Read on interact: replying or reacting marks the chat as read

### Spy essentials

- Deleted messages stay in the chat, marked as deleted
- Edit history of every edited message
- One-time and self-destructing photos and videos are kept and can be reopened
- In ghost mode, opening them neither tells the sender nor starts the timer
- Screenshots in chats that restrict saving content

### Chat

- Selection bar: choose and reorder its buttons
- Message menu: choose and reorder its actions
- Shot: share messages as an image

### Notifications

- Local notifications while ecoGram stays in the background
- Cleared once the chat is read on another device

### Appearance

- Dynamic Island profile animation on any iPhone
- Hide profile suggestions in Settings

### Badges

- ecoGram badges: developer, official channel and the first 30 users
- AyuGram badges
- Choose whose badges to show and their order next to Telegram's

## Privacy

No analytics. Message history stays on the device.

The only ecoGram server is `api.ecogram.cc`. It serves the public badge list, and the app sends it your Telegram ID to hand out the early user badge until the server answers. AyuGram badges come from the AyuGram server, or exteraGram's as a fallback. Turning a badge source off stops its requests.

## Install

Download the IPA from [releases](../../releases) and sign it with SideStore, AltStore, Sideloadly, Feather or ESign.

## Build

GitHub Actions: run the `Build` workflow with the `TELEGRAM_API_ID` and `TELEGRAM_API_HASH` secrets set. Swiftgram updates are pinned daily by the `Upstream` workflow.

Locally, on a Mac with Python 3.11+, `librsvg` (`brew install librsvg`) and the Xcode version from Swiftgram's `versions.json`:

```bash
python -m Tools.ecogram prepare
```

```bash
TELEGRAM_API_ID=… TELEGRAM_API_HASH=… python -m Tools.ecogram build
```

Editing patches: check out the pinned Swiftgram with patches applied, commit changes there, then write them back to `Patches/`.

```bash
python -m Tools.ecogram sync
```

```bash
python -m Tools.ecogram export
```

## Structure

| Path | |
| --- | --- |
| `EcoGram/Ayu/` | AyuGram features |
| `EcoGram/Settings/` | ecoGram settings |
| `EcoGram/Preferences/` | Preferences |
| `EcoGram/ContextMenu/` | Message menu |
| `EcoGram/Notifications/` | Local notifications |
| `EcoGram/Badges/` | ecoGram badges |
| `EcoGram/Strings/` | Strings: en, ru, ja |
| `Patches/` | Swiftgram patches |
| `Branding/` | Icons and names |
| `Tools/ecogram/` | Build tooling |

## Credits

[Telegram](https://github.com/TelegramMessenger/Telegram-iOS), [Swiftgram](https://github.com/Swiftgram/Telegram-iOS), [AyuGram](https://github.com/AyuGram/AyuGramDesktop).

## License

GPL-2.0. AyuGram badges and logo are from AyuGram Desktop (GPL-3.0).
