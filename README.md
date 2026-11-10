# BiscuitTab

Windows-style Alt-Tab window switcher for macOS, modeled on [AltTab](https://alt-tab.app/). Menu bar item (⇥) sets shortcut and style.

## Features

- Option+Tab cycles every window (Shift reverses, arrows move, Return or releasing Option switches, Esc cancels, click picks).
- Includes minimized, hidden and other-Space windows, with a badge (Minimized / Hidden / Space N).
- Full-size preview of the selected window.
- Option+` cycles windows of the current app only.
- Type while open to search window titles.
- Styles: thumbnails, app icons, title list. The grid auto-sizes to the screen.
- Shortcut modifier: Option, Control or Command.

## Permissions

Accessibility (hotkey + raising windows) and Screen Recording (titles + previews). Without Screen Recording, window titles are blank and minimized / other-Space windows are hidden.

## Build

CI builds a universal `.app` on every push and signs it ad-hoc (free, no Apple account). Get `BiscuitTab.zip` from the Actions artifacts, or push a `v*` tag to publish a release. Local: `swift build -c release`.

First launch: right-click the app > Open. Ad-hoc signatures change per build, so macOS may ask you to re-grant permissions after each update.

## Known limits

- Selecting a window on another Space jumps to the app's last-used window there, not always the exact one.
- Untested on a real Mac so far; expect compile fixes on the first CI run.
