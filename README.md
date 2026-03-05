<div align="center">

# 🦎 Lizard Companion for macOS

An expressive menu bar pet that reacts to what you're doing on your Mac.

<p>
  <img src="docs/images/hero-lizard.png" width="220" alt="Lizard Companion" />
</p>

<p>
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2015%2B-0F172A?style=for-the-badge&logo=apple&logoColor=white"/>
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.0-F97316?style=for-the-badge&logo=swift&logoColor=white"/>
  <img alt="License" src="https://img.shields.io/badge/license-MIT-10B981?style=for-the-badge"/>
</p>

<p>
  <img alt="mint" src="https://img.shields.io/badge/theme-Mint%20Gecko-34D399?style=flat-square"/>
  <img alt="teal" src="https://img.shields.io/badge/mood-Ambient%20%26%20Reactive-14B8A6?style=flat-square"/>
  <img alt="pixel" src="https://img.shields.io/badge/art-Pixel%20Sprite%20System-22C55E?style=flat-square"/>
</p>

</div>

---

## Features

- Animated companion in your menu bar (not a static icon)
- Context-aware states for real workflows
- Spotify reaction mode with just-in-time permission request
- Calendar reminder reactions
- Battery-aware animation throttling for better efficiency
- Rich clip catalog with app-specific expressions

## App-Aware States

The companion adapts to app categories and specific apps on your Mac:

- Coding: Xcode, Cursor, Terminal, iTerm, Warp
- Git sync: GitHub Desktop
- AI assistants: ChatGPT, Codex, Claude, LM Studio, Ollama
- Meetings: Microsoft Teams, Outlook
- Productivity docs: Word, Pages, Keynote, PowerPoint
- Spreadsheets: Excel, Numbers
- Browser/research: Safari, Chrome, Firefox, Perplexity
- Communication: Discord, Telegram, WhatsApp
- Racing/media: MultiViewer
- Security: NordVPN, Tailscale
- Launcher: Raycast

## Animation Catalog

Core clips:

- `idle_blink`, `sleep`
- `code_mac`, `code_terminal`, `code_cursor`
- `music_headphones`, `battery_worry`, `charge_recover`
- `meeting_wave`, `meeting_urgent`
- `browse_think`, `chat_talk`

Extended clips:

- `celebrate_fireworks`, `focus_deep`, `notify_ping`
- `compile_wait`, `break_stretch`
- `ai_assistant`, `meeting_call`
- `docs_write`, `sheet_crunch`
- `launch_fast`, `racing_watch`, `github_sync`, `secure_shield`

<p align="center">
  <img src="docs/images/sprite-strip.png" alt="Sprite strip preview" width="760" />
</p>

## Install (No Xcode Required for Daily Use)

You only need Xcode once to build. After that, run like a normal app from `/Applications`.

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
cd "Menu bar Companion app"
xcodebuild -scheme "Menu bar Companion app" -configuration Release -derivedDataPath build clean build
cp -R "build/Build/Products/Release/Menu bar Companion app.app" /Applications/
open /Applications/"Menu bar Companion app.app"
```

If macOS blocks first launch: right-click app in `/Applications` -> **Open**.

## Download (DMG)

For end users, use the DMG from GitHub Releases:

- Direct download (latest): [LizardCompanion-macOS.dmg](https://github.com/zabrodsk/lizard-companion-macos/releases/latest/download/LizardCompanion-macOS.dmg)
- SHA256 checksum: [LizardCompanion-macOS.dmg.sha256](https://github.com/zabrodsk/lizard-companion-macos/releases/latest/download/LizardCompanion-macOS.dmg.sha256)
- Releases page: [github.com/zabrodsk/lizard-companion-macos/releases](https://github.com/zabrodsk/lizard-companion-macos/releases)
- Drag the app into `/Applications`

Maintainers can produce a DMG locally with:

```bash
./scripts/make-dmg.sh
```

This creates:

- `dist/LizardCompanion-macOS.dmg`
- `dist/LizardCompanion-macOS.dmg.sha256`

## Permissions

The app requests permissions only when related features are enabled:

- Apple Events: Spotify playback state
- Calendar: upcoming meeting reminders

## Battery Impact

Animation is lightweight (tiny pixel frames), and the app includes power-aware throttling:

- Slower animation when unplugged
- Stronger slowdown on low battery
- Subtle mode further reduces animation intensity

## Project Structure

```text
Menu bar Companion app/
├─ Menu bar Companion app.xcodeproj/
├─ Menu bar Companion app/
│  ├─ Companion/
│  │  ├─ Animation/
│  │  ├─ Engine/
│  │  ├─ Models/
│  │  ├─ Services/
│  │  └─ UI/
│  └─ Assets.xcassets/
└─ README.md
```

## Roadmap

- Notch/desktop cameo mode (optional)
- More character packs and themes
- Additional integrations (tasks, git, notifications)
- DMG packaging + notarized release builds

## License

MIT — see [LICENSE](LICENSE)
