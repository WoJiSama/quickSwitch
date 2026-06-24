# quickSwitch

![platform](https://img.shields.io/badge/platform-macOS%2013%2B-black?logo=apple)
![swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift)
![tests](https://img.shields.io/badge/tests-48%20passing-brightgreen)
![permissions](https://img.shields.io/badge/permissions-none-blue)
![license](https://img.shields.io/badge/license-MIT-lightgrey)
[![community: linux.do](https://img.shields.io/badge/community-linux.do-ffb700?logo=discourse&logoColor=white)](https://linux.do)

A lightweight macOS floating **mini-dock**. Pin the apps, files, folders, and web
pages you jump to most; click one to switch or open it. No Dock icon, no menu-bar
clutter — just a draggable bar that stays where you put it, snaps to a screen edge to
auto-hide, and goes horizontal or vertical.

It uses **no sensitive permissions** — no Accessibility, no screen recording, no
automation. Switching and opening go through the same system path the Dock uses
(`NSWorkspace` / LaunchServices), and global hotkeys use Carbon's standard hotkey API.

> 🇨🇳 中文使用教程见 [docs/使用教程.md](docs/使用教程.md)。

## Contents

- [Highlights](#highlights)
- [Install & run](#install--run)
- [Usage](#usage)
- [Global hotkeys](#global-hotkeys)
- [Settings](#settings)
- [Edge auto-hide](#edge-auto-hide)
- [Build from source](#build-from-source)
- [Architecture](#architecture)
- [Privacy](#privacy)
- [Troubleshooting](#troubleshooting)
- [Community](#community)
- [License](#license)

## Highlights

- **Four kinds of entries** — apps (activate/launch like the Dock), files (open with
  the default app), folders (reveal in Finder), and web links (open in the default
  browser).
- **Add without hassle** — drag from Finder, click `+`, or right-click the bar →
  *Add running app* / *Add file or app…* / *Add URL…* (paste a link).
- **Global hotkeys** — a configurable summon hotkey (default `⌥Space`) and
  modifier+`1`…`9` direct-open. Hold the digit modifier to light up the bar and show
  number badges, then press a digit. No Accessibility permission required.
- **Live tuning** — a Settings window with sliders for icon size, corner radius,
  background opacity, spacing, and padding; horizontal or vertical layout; show/hide
  the `+`; always-on-top; menu-bar icon; launch at login.
- **Edge auto-hide** — drag the bar to the left/right screen edge and it slides away to
  a thin sliver; move the cursor near it (or drag something toward it) to reveal.
- **Designed feel** — hover magnification with name labels, drag-to-reorder, rename,
  and clear visual feedback: red flash on open failure, shake on invalid drop,
  gray-out for removed/uninstalled targets, ring flash on duplicate add. Honors
  *Reduce Motion*.
- **Remembers everything** — entries, style, layout, and the bar's last position /
  edge state all persist across launches.
- **Light & private** — native Swift, zero third-party dependencies, a pure
  unit-tested core, and no sensitive permissions.

## Install & run

Pre-built distribution requires a Developer ID signature + notarization, which this
project doesn't ship — so build it yourself (see [below](#build-from-source)). The
short version:

```bash
./scripts/bundle.sh          # produces build/quickSwitch.app
open build/quickSwitch.app
```

quickSwitch runs as a background accessory: it has **no Dock icon** and isn't in
`⌘Tab`. You drive it through the floating bar plus a menu-bar grid icon (a fallback
entry for Settings / tutorial / quit / re-center). On first launch the bar appears at
the top-center of the screen, empty except for a hint and a `+`, and the tutorial pops
up once.

To quit: right-click the bar → *Quit quickSwitch*, or use the menu-bar icon.

## Usage

| Do this | Action |
|---|---|
| Switch / open an entry | **Left-click** its icon |
| Reorder | **Drag** an icon over another |
| Move the whole bar | **Drag any empty space** on the bar (not an icon) |
| Add an app / file / folder | Drag from **Finder**, or click **`+`** |
| Add a running app | **Right-click** the bar ▸ *Add running app* |
| Add a web page | **Right-click** the bar ▸ *Add URL…* (paste a link) |
| Rename | **Right-click** an icon ▸ *Rename…* |
| Remove | **Right-click** an icon ▸ *Remove* |
| See an entry's name | **Hover** its icon |
| Hide a frontmost app | **Click its icon again** (A↔B toggling; can be disabled) |
| Open Settings | **Right-click** the bar ▸ *Settings…* |
| Lost the bar? | **Menu-bar icon** ▸ *Bring the bar back to center* |

> **Two macOS limitations (not bugs):**
> - Dragging an app icon out of the **macOS Dock** doesn't work — macOS doesn't hand
>   off Dock items to third-party windows. Use *Add running app*, or drag from Finder.
> - Dragging a browser **tab** tears it into a new window (browser behavior). Drag the
>   **address-bar URL** instead, or use *Add URL…*.

## Global hotkeys

| Hotkey | What it does |
|---|---|
| `⌥Space` | **Summon** — the bar pulses and shows number badges under the first nine icons; if it's edge-hidden it slides out (press again to slide back). It never hides a floating bar. |
| *modifier* + `1`…`9` | **Direct-open** entries 1–9 without summoning the bar. |
| *hold the modifier* | **Selection mode** — the bar highlights and shows live `1, 2, 3…` badges so you can see what each digit maps to, then press a number. |

Both the summon hotkey and the digit modifier are configurable in
**Settings → Hotkeys**. The summon hotkey is fully re-recordable (click the field and
press any modifier combo). The digit modifier can be `⌥` (default), `⌃`, `⌃⌥`, `⌘⌥`,
or `⌃⌘`; the Settings panel warns if your choice collides with the system's
"Switch to Desktop N" shortcuts (which occupy `⌃`+digit by default). Either hotkey
can be turned off independently.

Hotkeys use Carbon's `RegisterEventHotKey` and modifier-flag polling — both
**permission-free**, so there's no Accessibility prompt.

## Settings

Right-click the bar → *Settings…*. Everything saves automatically and is reused on the
next launch.

- **Layout** — horizontal / vertical orientation; show or hide the `+` button.
- **Size & style** (live sliders) — icon size, corner radius, background opacity, icon
  spacing, inner padding. *Reset style* restores the defaults.
- **Hotkeys** — record the summon hotkey; pick the digit modifier; toggle each on/off.
- **Behavior** — always-on-top; menu-bar icon; "hide a frontmost app on re-click"
  (A↔B toggling); launch at login.

## Edge auto-hide

Drag the whole bar to the far **left or right edge** and release: it slides off-screen,
leaving a thin sliver as a handle.

- Move the cursor **near the sliver** and it slides back out.
- Move away and, after a beat, it tucks back in.
- Drag something toward it and it pops out so you can drop onto it.
- To pull it back to the middle: let it reveal, then drag an empty area to the center.

Left in the middle of the screen, the bar stays put and never auto-hides.

## Build from source

### Requirements

- macOS 13 (Ventura) or later.
- A Swift 5.9+ toolchain. Full Xcode is **not** required — a swift.org toolchain via
  [swiftly](https://www.swift.org/install/macos/swiftly/) works (this project was built
  that way). Note: the bare Command Line Tools alone may ship a SwiftPM/XCTest that
  can't build or test this package; a healthy swift.org toolchain avoids that.

### Develop

```bash
swift test            # run the unit-tested core (Swift Testing — 48 tests)
swift build           # compile
swift run quickSwitch # run from source (Ctrl+C to quit)
```

### Bundle a distributable .app

```bash
./scripts/bundle.sh   # produces build/quickSwitch.app (ad-hoc signed, LSUIElement)
open build/quickSwitch.app
```

> **Gatekeeper note:** the bundle is only ad-hoc signed. Opening it on the build
> machine is fine, but if you distribute it (download / AirDrop), the first launch is
> blocked. Recipients use System Settings → Privacy & Security → *Open Anyway*, or run
> `xattr -dr com.apple.quarantine quickSwitch.app`. Proper distribution needs a
> Developer ID signature + notarization.

## Architecture

A Swift Package with two targets:

- **`QuickSwitchCore`** — pure, fully unit-tested logic with system access behind
  protocols: `AppItem` (the app/path/url entry model), `AppListStore` (persistence),
  `AppSwitcher` + `WorkspaceProviding` (open via LaunchServices), `AppResolver`
  (`.app` URL → entry), `PreferencesStore`, `LoginItemControlling`.
- **`quickSwitch`** — an AppKit accessory app hosting SwiftUI inside a borderless,
  floating `NSPanel`: `DockBarView` / `DockIconView` (the bar and its icons),
  `EdgeDockController` (edge auto-hide), `WindowDragHandle` (drag-to-move),
  `HotKeyCenter` / `HotKeyRecorder` (Carbon hotkeys), `SettingsView`,
  `StatusItemController` (menu-bar icon), and more.

Because all system access sits behind protocols, the core is covered by unit tests
(Swift Testing); the AppKit/SwiftUI shell is verified by running. See
[`docs/superpowers/specs/`](docs/superpowers/specs/) and
[`docs/superpowers/plans/`](docs/superpowers/plans/) for the design and build plan.

## Privacy

quickSwitch opens and switches apps only through standard system APIs (`NSWorkspace`).
It needs **no Accessibility, screen-recording, or automation permissions**, makes no
network requests, and collects no data. Your list of entries and preferences live in
local `UserDefaults` and never leave your machine.

## Troubleshooting

**An app won't switch when clicked.** quickSwitch uses the same system path as the
Dock, but a rare app may misbehave depending on which Space it's on or its window
state. To see what's happening:

```bash
log stream --predicate 'subsystem == "com.shiqi.quickSwitch"' --level info
```

Click the failing icon and watch the output:

- `openApp <id> -> urlForApplication is NIL` — LaunchServices doesn't recognize the
  app; remove it and re-add via *Add running app*.
- `openApp <id> FAILED: …` — the specific error follows.
- `openApp <id> -> ok` but no switch — the app is likely on another Space or
  full-screen (a system-level limitation).

Press `Ctrl+C` to stop.

## Community

quickSwitch is shared and discussed on the **[linux.do](https://linux.do)** community.
Questions, bug reports, and feature ideas are welcome there — come say hi.

> 🇨🇳 本项目也在 **[linux.do](https://linux.do)** 社区分享与讨论,欢迎在那里交流、反馈问题或提需求。

## License

Released under the [MIT License](LICENSE).
