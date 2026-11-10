# YetAltTab

<img src="assets/icon.png" width="128" alt="YetAltTab logo">

Repo: [mfatihas/yet-alt-tab](https://github.com/mfatihas/yet-alt-tab). Windows-style Alt-Tab window switcher for macOS, modeled on [AltTab](https://alt-tab.app/). Menu bar item (⇥) sets shortcut and style.

## Features

- Option+Tab cycles every window (Shift reverses, arrows move, Return or releasing Option switches, Esc cancels, hovering selects and previews, click picks).
- Includes minimized, hidden and other-Space windows, with a badge (Minimized / Hidden / Space N).
- Full-size preview of the selected window (toggle in the menu bar item).
- Option+` cycles windows of the current app only.
- Type while open to search window titles.
- Styles: thumbnails, app icons, title list. The grid auto-sizes to the screen.
- Auto-update from GitHub releases (daily check, or "Check for Updates" in the menu).
- Size (small, medium, large) and theme (system, light, dark).
- Shortcut modifier: Option, Control or Command.

## Permissions

Accessibility (hotkey + raising windows) and Screen Recording (titles + previews). Without Screen Recording, window titles are blank and minimized / other-Space windows are hidden.

## Build

CI builds a universal `.app` in a `.dmg` on every push and signs it ad-hoc (free, no Apple account). Get `YetAltTab.dmg` from the Actions artifacts, or push a `v*` tag to publish a release. Local: `swift build -c release`.

First launch: macOS shows "Apple could not verify YetAltTab..." because the app isn't notarized (that needs a paid Apple Developer account). Either open System Settings > Privacy & Security and click "Open Anyway", or run `xattr -dr com.apple.quarantine /Applications/YetAltTab.app`. Right-click > Open no longer works on macOS 15+. Ad-hoc signatures change per build, so macOS may ask you to re-grant permissions after each update.

## Signing

Releases are ad-hoc signed, which is free but not trusted by Gatekeeper. Removing the warning needs a Developer ID certificate and notarization from the Apple Developer Program ($99/year). Apple has no free tier for open-source projects. SignPath Foundation (free for open source) only signs Windows binaries, and a self-signed certificate gives the same warning.

## Known limits

- Selecting a window on another Space jumps to the app's last-used window there, not always the exact one.
- Untested on a real Mac so far; expect compile fixes on the first CI run.

## License

[WTFPL](LICENSE). This is original code, not derived from AltTab (GPL-3.0), so it can use a different license.
