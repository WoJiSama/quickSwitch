# quickSwitch

A lightweight macOS floating mini-dock. Pin the apps, files, folders, and web pages
you jump to most; click one to switch/open it. No Dock icon, no menu-bar clutter —
just a draggable bar that stays where you put it, can snap to a screen edge and
auto-hide, and goes horizontal or vertical.

> 中文使用教程见 [docs/使用教程.md](docs/使用教程.md)。

## Highlights

- **Four kinds of entries:** apps (activate/launch like the Dock), files (open with
  default app), folders (reveal in Finder), and web links (open in default browser).
- **Add without hassle:** drag from Finder, click `+`, or right-click → *Add running
  app* / *Add file or app…* / *Add URL…* (paste a link).
- **Live tuning:** Settings window with sliders for icon size, corner radius,
  background opacity, spacing, and padding; horizontal/vertical layout; show/hide `+`.
- **Edge auto-hide:** drag the bar to the left/right screen edge and it slides away to
  a thin sliver; move the cursor near it (or drag something toward it) to reveal.
- **Designed feel:** hover magnification + name labels, drag-to-reorder, rename,
  and visual feedback (red flash on open failure, shake on invalid drop, gray-out for
  removed/uninstalled targets, flash on duplicate add).
- **Light & private:** native Swift, no third-party dependencies, no sensitive
  permissions (uses `NSWorkspace`/LaunchServices only — no Accessibility/screen capture).

## Requirements

- macOS 13 (Ventura) or later
- A Swift 5.9+ toolchain. Full Xcode is **not** required — a swift.org toolchain via
  [swiftly](https://www.swift.org/install/macos/swiftly/) works (this project was built
  that way). Note: SwiftPM commands need a healthy toolchain; the bare Command Line
  Tools alone may not include a working SwiftPM/XCTest.

## Develop

```bash
swift test            # run the unit-tested core (Swift Testing)
swift build           # compile
swift run quickSwitch # run the app from source (Ctrl+C to quit)
```

## Build a distributable .app

```bash
./scripts/bundle.sh   # produces build/quickSwitch.app (ad-hoc signed, LSUIElement)
open build/quickSwitch.app
```

## Usage (quick reference)

| Do this | Action |
|---|---|
| Switch / open an entry | **Left-click** its icon |
| Reorder | **Drag** an icon over another |
| Move the whole bar | **Drag any empty space** on the bar |
| Add an app/file/folder | Drag from **Finder**, or click **`+`** |
| Add a running app | **Right-click** the bar ▸ *Add running app* |
| Add a web page | **Right-click** the bar ▸ *Add URL…* (paste a link) |
| Rename | **Right-click** an icon ▸ *Rename…* |
| Remove | **Right-click** an icon ▸ *Remove* |
| Style / layout | **Right-click** the bar ▸ *Settings…* |
| Edge auto-hide | Drag the bar to the **left/right edge**; hover near it to reveal |

> Dragging app icons out of the **macOS Dock** does not work — macOS doesn't hand off
> Dock items to other apps. Use *Add running app* or drag from Finder instead.
> Dragging a browser **tab** tears it into a new window (browser behavior); drag the
> **address-bar URL** or use *Add URL…* instead.

## Architecture

- **`QuickSwitchCore`** — pure, unit-tested logic: `AppItem` (app/path/url entry),
  `AppListStore` (persistence), `AppSwitcher` + `WorkspaceProviding` (open via
  LaunchServices), `AppResolver` (URL → entry), `PreferencesStore`, `LoginItemControlling`.
- **`quickSwitch`** — AppKit accessory app hosting SwiftUI inside a borderless,
  floating `NSPanel`: `DockBarView` / `DockIconView` (bar + icons), `EdgeDockController`
  (edge auto-hide), `WindowDragHandle` (drag-to-move), `SettingsView`/`SettingsWindowController`.

System access is behind protocols so the core is fully unit-tested; the AppKit/SwiftUI
shell is verified by running. See `docs/superpowers/specs/` and `docs/superpowers/plans/`
for the design and build plan.
