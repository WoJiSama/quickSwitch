# quickSwitch

A lightweight macOS floating mini-dock. Add the apps you switch between most; click an icon to jump to that app (it launches the app if it isn't running). No Dock icon, no menu-bar clutter — just a draggable bar that stays where you put it.

## Requirements

- macOS 13 (Ventura) or later
- Swift toolchain (Xcode command-line tools)

## Develop

```bash
swift test           # run the unit-tested core
swift run quickSwitch # run the app from source
```

## Build a distributable .app

```bash
./scripts/bundle.sh   # produces build/quickSwitch.app
open build/quickSwitch.app
```

## Usage

- **Add an app:** drag a `.app` onto the bar, or click `+` and pick one.
- **Switch:** click an icon.
- **Reorder:** drag one icon over another.
- **Remove:** right-click an icon ▸ 移除.
- **Settings:** right-click the bar ▸ icon size, always-on-top, open-at-login, quit.
- **Move the bar:** drag its background.

## Architecture

- `QuickSwitchCore` — pure, unit-tested logic: models, stores, services (system access is protocol-injected).
- `quickSwitch` — AppKit accessory app hosting SwiftUI inside a borderless `NSPanel`.

See `docs/superpowers/specs/` and `docs/superpowers/plans/` for the design and build plan.
