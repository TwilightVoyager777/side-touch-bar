# Side Touch Bar

English | [简体中文](README.zh-CN.md)

[![CI](https://github.com/TwilightVoyager777/side-touch-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/TwilightVoyager777/side-touch-bar/actions/workflows/ci.yml)

The MacBook Touch Bar, back as a vertical Liquid Glass bar on the right edge of the screen — designed for the touch-screen Macs to come, and usable with a mouse today.

The layout follows the original Touch Bar, turned on its side: **esc → app controls → Control Strip**, top to bottom.

## Features

- **Control Strip** — brightness, volume, mute and Siri; expand for the full Touch Bar strip (Mission Control, Launchpad, keyboard brightness, media keys). Tap brightness or volume for a slider, or press and drag to adjust. Customizable, with screenshot, lock, Spotlight, Night Shift, dark mode, input source, Shortcuts and more.
- **App controls** that follow the frontmost app: browsers, Finder, terminals, Mail, Calendar, Preview, Messages, Notes, Keynote, Calculator, Photos, and paged sets for **VS Code / Cursor / Zed, JetBrains IDEs and Xcode** (run, navigate, edit, Git, AI, and a debugger page that comes forward while debugging).
- **Browsers** — open tabs as a list, a touch scroll pad, zoom, find, tools, favorite sites, and "send this page to AI".
- **Playback controls in one style for every app** — album art, a scrubber, transport buttons, volume, playback speed, full screen, picture in picture, subtitles, shuffle/repeat and audio output switching. Appears while the frontmost app plays; media playing elsewhere gets a Now Playing button, like on the Touch Bar.
- **AI coding**
  - With Claude Code, Codex, OpenCode or Gemini running in a terminal: **Yes / Always allow / No**, cycle permission mode, voice input, screenshots and one-tap prompts or slash commands.
  - Claude, OpenCode and ChatGPT desktop apps: new session, search, switch sessions, sidebar, terminal, changes — pressed through their menus, so they survive shortcut changes.
  - **Hold-to-talk voice input** (on-device speech recognition when available) and **send selected code** with its file path to the AI tool you used last.
  - **Status alerts** (optional, installed from Settings): the edge handle turns orange when an agent needs approval, green when it's done, blue while it runs; the bar slides out with Yes/No when approval is needed; a session list jumps to each terminal; Claude Code context usage.
- **Touch** — risky buttons need a 0.6 s hold (lock, delete, always allow…), volume/zoom/skip repeat while held, a text page with an iPhone-style cursor pad appears while typing, and you can swipe in from the edge to reveal the bar.
- **Touch Bar settings** — what the bar shows (app controls with Control Strip, expanded Control Strip, app controls, F-keys, Quick Actions, Spaces), what holding **fn** shows, and apps that always show F-keys.
- **Custom buttons** for any app, picked from its menus, recorded shortcuts, or text.
- **Sized for 14"/16" MacBook Pro** (44 pt ≈ 8.8 mm touch targets) and adapted to other displays by physical size; it shrinks rather than clipping.
- **English and Chinese** interface.

## Install

Requires **macOS 26** or later. Universal: Apple silicon and Intel.

### Download

1. Get the latest `SideTouchBar-x.y.z.dmg` (or `.zip`) from [Releases](https://github.com/TwilightVoyager777/side-touch-bar/releases) and drag SideTouchBar into Applications.
2. The app isn't notarized by Apple, so macOS blocks the first launch. Open it once, then go to **System Settings › Privacy & Security** and click **Open Anyway** — or run
   `xattr -dr com.apple.quarantine /Applications/SideTouchBar.app`
3. Grant **Accessibility** when asked. Settings › Start lists every permission and what it's for.

### From source

Only Apple's Command Line Tools are needed (`xcode-select --install`), not Xcode:

```bash
git clone https://github.com/TwilightVoyager777/side-touch-bar.git
cd side-touch-bar
scripts/install.sh        # or: make install
```

It builds the app, installs it into /Applications (or ~/Applications) and opens it.

### Uninstall

```bash
scripts/uninstall.sh      # or: make uninstall
```

It first removes any AI status integrations (restoring your Claude Code, OpenCode and Codex settings) and the login item, then the app, its preferences, data and granted permissions.

## Permissions and privacy

| Permission | Used for |
|---|---|
| **Accessibility** (required) | Sending shortcuts and media keys, pressing menu items, detecting the fn key, reading browser tabs and text focus |
| Microphone + Speech Recognition | Hold-to-talk voice input |
| Screen Recording | Screenshot to AI |

The app makes no network requests (other than opening links you choose). Some features rely on private or unusual system interfaces, and may stop working in a future macOS:

- **Now Playing**: since macOS 15.4, MediaRemote only answers Apple-signed processes, so a small helper library (`Helpers/NowPlayingHelper.m`) is loaded into the system's `/usr/bin/perl` to read playback information. Commands (play/pause, seek) are sent directly.
- **Display and keyboard brightness, Night Shift, dark mode, Spaces**: private frameworks (DisplayServices, CoreBrightness, SkyLight), with fallbacks to simulated keys.

For these reasons the app can't be distributed through the Mac App Store.

## AI status alerts

Installed per tool from Settings › AI Coding, after a confirmation that says exactly what changes. Every edited file is backed up first, and everything can be removed from the same place (or by `scripts/uninstall.sh`).

| Tool | Change |
|---|---|
| Claude Code status | One async command hook for each of 9 events in `~/.claude/settings.json` |
| Claude Code context usage | Wraps `statusLine`; your original status line keeps printing |
| OpenCode status | Adds `~/.config/opencode/plugins/sidetouchbar.js`; your configuration isn't changed |
| Codex completion | Adds a `notify` line to `~/.codex/config.toml` (skipped if you already have one) |

Hooks only write events while Side Touch Bar is running, into `~/Library/Application Support/SideTouchBar/agents/`.

## Development

```bash
make run          # debug build, then open it (scripts/build-app.sh debug)
make build        # release build in build/SideTouchBar.app
make test         # translation check + Swift Testing suite (scripts/test.sh)
make package      # universal build packaged as dist/*.dmg and *.zip
.build/debug/SideTouchBar --sizing-report --verbose   # bar heights on common displays
```

- **Stable signing**: ad hoc signed builds may lose their permissions on every rebuild. Run `scripts/create-signing-identity.sh` once to create a local self-signed certificate that `build-app.sh` then uses automatically.
- **Tests** cover the integration installer (against a temporary home directory — never your real config), session status, agent detection, models, sizing and translations.
- **Localization**: Chinese is the source language; English lives in `Sources/SideTouchBar/App/L10n+English.swift`. Run `scripts/check-l10n.py` after adding interface text.
- **Adding app buttons**: presets are in `Sources/SideTouchBar/Actions/AppPresets.swift`, `IDEPresets.swift` and `Sources/SideTouchBar/AI/AIPresets.swift`, matched by bundle ID (`osascript -e 'id of app "Safari"'`).
- **Releasing**: bump `CFBundleShortVersionString` in `Resources/Info.plist`, update `CHANGELOG.md`, then push a tag such as `v0.2.0`. GitHub Actions tests, packages and publishes the release.

```
Sources/SideTouchBar/
  App/       entry point, menu bar, settings model, localization
  Settings/  settings window
  Bar/       edge panel, reveal/hide, sizing, preset resolution
  UI/        Liquid Glass SwiftUI views
  Actions/   buttons, app and IDE presets, actions
  AI/        agent detection, AI pages, voice input, session status, integrations
  System/    keys, menus, text input, processes, media, audio, brightness, permissions…
Helpers/     Now Playing helper library (built by build-app.sh)
Tests/       Swift Testing suite
```

## Known limitations

- Not yet verified on real installs: the IDE presets, the ChatGPT desktop app, Codex keys and alerts, and OpenCode's terminal approval keys. Debugger pages switch automatically only when the app keeps its menu state current; the page button always works.
- The original Touch Bar's typing suggestions and app-provided scrubbers can't be reproduced: apps only build that content when Touch Bar hardware is present.
- Holding **fn** doesn't work on keyboards that handle fn internally (many third-party keyboards).
- macOS can't reserve screen space for the bar, so it floats above windows and hides automatically; a Dock on the right edge conflicts with it.

## License

[MIT](LICENSE)
