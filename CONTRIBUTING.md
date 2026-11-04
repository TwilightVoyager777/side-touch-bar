# Contributing

Thanks for helping improve Side Touch Bar. Bug reports, presets for more apps, translations and fixes are all welcome.

## Development setup

You need macOS 26 or later and Apple's Command Line Tools (`xcode-select --install`). Xcode is optional.

```bash
make run          # debug build, then open it
make test         # translation check + test suite
make build        # release build in build/SideTouchBar.app
make package      # universal build packaged in dist/
```

Ad hoc signed builds may lose their permissions on every rebuild. Run `scripts/create-signing-identity.sh` once to sign with a local certificate instead.

Useful developer commands:

| Command | Purpose |
|---|---|
| `.build/debug/SideTouchBar --sizing-report --verbose` | Height of every bar state on common displays |
| `.build/debug/SideTouchBar --render-previews docs/images` | Regenerate the README preview images |
| `python3 scripts/check-l10n.py` | Find missing, duplicate or unused translations |

## Project layout

| Path | Contents |
|---|---|
| `Sources/SideTouchBar/App` | Entry point, menu bar, settings model, localization |
| `Sources/SideTouchBar/Settings` | Settings window |
| `Sources/SideTouchBar/Bar` | Edge panel, reveal/hide, sizing, preset resolution |
| `Sources/SideTouchBar/UI` | SwiftUI views |
| `Sources/SideTouchBar/Actions` | Buttons, app and IDE presets, actions |
| `Sources/SideTouchBar/AI` | Agent detection, AI pages, voice input, session status, integrations |
| `Sources/SideTouchBar/System` | Keys, menus, text input, processes, media, audio, brightness, permissions |
| `Helpers` | Now Playing helper library |
| `Tests` | Swift Testing suite |

## Adding buttons for an app

1. Find the bundle ID: `osascript -e 'id of app "App Name"'`.
2. Add an `AppPreset` to `AppPresets.swift` (or `IDEPresets.swift` for programming tools) and include it in `all`.
3. Prefer **menu items** (`.menu("Title", "symbol", ["Menu", "Item"], fallback: …)`) over raw shortcuts: they keep working when an app changes its shortcuts and when its menus are localized (list alternatives with `|`). Use `.repeating()` for actions people hold down and `.confirming()` for destructive ones.
4. Keep each page to about nine buttons; split larger sets into pages.
5. Check the height with `--sizing-report --verbose`: the tallest state must fit 908 pt (a 14" MacBook Pro at its default resolution) at scale 1.
6. Add English translations for any new labels.

Please mention in the pull request whether you verified the buttons in the real app.

## Localization

Chinese is the source language. Every user-facing string goes through `tr()`, and its English text lives in `Sources/SideTouchBar/App/L10n+English.swift`. Use format placeholders (`tr("桌面 %d", number)`) instead of string interpolation, and run `scripts/check-l10n.py` before committing; the tests check that placeholders match.

## Code conventions

- Follow the style of the surrounding code; keep views small and state in `ObservableObject`s. The project builds with the Command Line Tools, where SwiftUI's `@State` macro isn't available — use `BarState` or another observable object instead.
- Comment only what isn't obvious from the code.
- Anything that edits files outside the app (like the AI integrations) must back up first, be reversible, and be covered by tests that run against a temporary directory.

## Commits and pull requests

- Write commit messages in English, in the imperative mood ("Add Safari reading list button"), with a short body explaining why when it isn't obvious.
- Make sure `make test` passes and the app builds.
- Include a screenshot for visual changes.

## Reporting bugs

Use the bug report template and include your macOS version, Mac model and display, how you installed the app, and the app involved.
