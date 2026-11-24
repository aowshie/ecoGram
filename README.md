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

<img src="Branding/Readme/swiftgram.png" width="16" height="16"> Swiftgram &nbsp; <img src="Branding/Readme/ayugram.svg" width="16" height="16"> AyuGram &nbsp; <img src="Branding/Readme/ecogram.svg" width="16" height="16"> ecoGram

### <img src="Branding/Readme/swiftgram.png" width="20" height="20"> Swiftgram

- The base: every Swiftgram feature and setting is kept

### <img src="Branding/Readme/ayugram.svg" width="20" height="20"> Ghost essentials

- Don't send read receipts, online status, typing or story views, each on its own
- Per-chat exceptions for every option
- Keep chats unread on this device too
- Read on interact: replying or reacting marks the chat as read

### <img src="Branding/Readme/ayugram.svg" width="20" height="20"> Spy essentials

- Deleted messages stay in the chat, marked as deleted
- Edit history of every edited message
- One-time and self-destructing photos and videos are kept and can be reopened
- <img src="Branding/Readme/ecogram.svg" width="14" height="14"> In ghost mode, opening them neither tells the sender nor starts the timer
- <img src="Branding/Readme/ecogram.svg" width="14" height="14"> Protected chats: screenshots, copying text and saving media where content is restricted
- <img src="Branding/Readme/ecogram.svg" width="14" height="14"> Forward from protected chats as a Shot image

### <img src="Branding/Readme/ecogram.svg" width="20" height="20"> Chat

- Selection bar: choose and reorder its buttons
- Message menu: choose and reorder its actions
- <img src="Branding/Readme/ayugram.svg" width="14" height="14"> Shot: share messages as an image, from the selection bar or the message menu
- <img src="Branding/Readme/ecogram.svg" width="14" height="14"> Shot options: theme, message tails, reactions, edited marks, your messages on either side, hidden names and photos, hidden badges, Shot from Here, up to 100 messages

### <img src="Branding/Readme/ecogram.svg" width="20" height="20"> Notifications

- Local notifications while ecoGram stays in the background
- Cleared once the chat is read on another device

### <img src="Branding/Readme/ecogram.svg" width="20" height="20"> Appearance

- Dynamic Island profile animation on any iPhone
- Hide profile suggestions in Settings

### <img src="Branding/Readme/ecogram.svg" width="20" height="20"> Badges

- ecoGram badges: developer, official channel and the first 30 users
- <img src="Branding/Readme/ayugram.svg" width="14" height="14"> AyuGram badges
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
