# quickSwitch Mini-Dock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight macOS background widget — a floating, always-on-top, draggable mini-dock of real app icons; clicking an icon switches to that app (activate if running, launch if not).

**Architecture:** Swift Package with two targets. `QuickSwitchCore` (a pure, fully unit-tested library: models, stores, services with protocol-injected system access) and `quickSwitch` (an AppKit executable that hosts SwiftUI views inside a borderless `NSPanel` and runs as an accessory app). A shell script bundles the executable into a distributable `.app`.

**Tech Stack:** Swift 5.9+, SwiftUI + AppKit, `NSWorkspace`, `UserDefaults`, `SMAppService`, Swift Testing. No third-party dependencies. macOS 13+.

---

## Deviations From Spec (intentional, for executability)

1. **SwiftPM instead of an Xcode project.** Makes the plan TDD-friendly (`swift test`) and text-authorable. The distributable `.app` (with `LSUIElement`) is produced by `scripts/bundle.sh` in the final task.
2. **Accessory mode set at runtime** via `NSApp.setActivationPolicy(.accessory)` (so even `swift run` behaves as a no-Dock-icon widget). The bundled `.app` also sets `LSUIElement` in Info.plist.
3. **Persist full `AppItem` JSON** (bundleID + displayName) rather than only bundleIDs, so the display name survives without re-reading the bundle. Icons are still fetched live by bundleID.
4. **Settings live in a right-click context menu** on the bar, not a separate popover view — same intent, even lighter and more idiomatic.
5. **Tests use Swift Testing** (`import Testing`, `@Test`, `#expect`), NOT XCTest. XCTest is not installed on this machine (no full Xcode), and Swift Testing is the project's mandated framework. The build/test toolchain is swiftly-managed Swift 6.3 (`~/.swiftly/bin`, already on PATH — NOT the broken Command Line Tools). Run commands still use `swift test` / `swift test --filter <SuiteName>`; the runner prints `Test run with N tests ... passed` (not XCTest's `Executed N tests` phrasing).

---

## File Structure

```
quickSwitch/
├── Package.swift
├── Sources/
│   ├── QuickSwitchCore/
│   │   ├── AppItem.swift              // immutable model
│   │   ├── WorkspaceProviding.swift   // protocol + SystemWorkspace (NSWorkspace impl)
│   │   ├── AppSwitcher.swift          // activate-vs-launch logic (unit tested)
│   │   ├── BundleInfoReading.swift    // protocol + SystemBundleInfoReader
│   │   ├── AppResolver.swift          // .app URL -> AppItem (unit tested)
│   │   ├── AppListStore.swift         // [AppItem] CRUD + UserDefaults (unit tested)
│   │   ├── PreferencesStore.swift     // icon size / always-on-top (unit tested)
│   │   └── LoginItemControlling.swift // protocol + SMAppService impl (system, manual)
│   └── quickSwitch/
│       ├── main.swift                 // entry: accessory policy + run
│       ├── AppDelegate.swift          // wires stores/services, shows panel
│       ├── DockPanel.swift            // borderless floating draggable NSPanel
│       ├── IconLoader.swift           // bundleID -> NSImage
│       ├── DockIconView.swift         // one icon: tap/right-click/drag
│       └── DockBarView.swift          // the bar: layout, add (+/drop), reorder, settings menu
├── Tests/
│   └── QuickSwitchCoreTests/
│       ├── AppItemTests.swift
│       ├── AppSwitcherTests.swift
│       ├── AppResolverTests.swift
│       ├── AppListStoreTests.swift
│       └── PreferencesStoreTests.swift
├── scripts/
│   └── bundle.sh                      // assemble quickSwitch.app with Info.plist
└── docs/...                           // spec + this plan
```

---

## Task 0: Swift Package scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/QuickSwitchCore/Placeholder.swift`
- Create: `Sources/quickSwitch/main.swift`
- Create: `Tests/QuickSwitchCoreTests/SmokeTests.swift`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "quickSwitch",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "QuickSwitchCore"),
        .executableTarget(
            name: "quickSwitch",
            dependencies: ["QuickSwitchCore"]
        ),
        .testTarget(
            name: "QuickSwitchCoreTests",
            dependencies: ["QuickSwitchCore"]
        ),
    ]
)
```

- [ ] **Step 2: Add a placeholder so the library target compiles**

Create `Sources/QuickSwitchCore/Placeholder.swift`:

```swift
// Replaced by real types in later tasks. Keeps the target non-empty.
enum QuickSwitchCore {}
```

- [ ] **Step 3: Add a minimal executable entry so the package builds**

Create `Sources/quickSwitch/main.swift`:

```swift
import Foundation

// Replaced in Task 7 with the real AppKit entry point.
print("quickSwitch scaffold")
```

- [ ] **Step 4: Write a smoke test**

Create `Tests/QuickSwitchCoreTests/SmokeTests.swift`:

```swift
import Testing
@testable import QuickSwitchCore

@Test func packageBuildsAndTestsRun() {
    #expect(Bool(true))
}
```

- [ ] **Step 5: Run the test suite**

Run: `swift test`
Expected: PASS — `Executed 1 test, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "chore: scaffold SwiftPM package (core lib + executable + tests)"
```

---

## Task 1: AppItem model

**Files:**
- Create: `Sources/QuickSwitchCore/AppItem.swift`
- Delete: `Sources/QuickSwitchCore/Placeholder.swift`
- Test: `Tests/QuickSwitchCoreTests/AppItemTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/QuickSwitchCoreTests/AppItemTests.swift`:

```swift
import Testing
import Foundation
@testable import QuickSwitchCore

struct AppItemTests {
    @Test func idEqualsBundleID() {
        let item = AppItem(bundleID: "com.google.Chrome", displayName: "Google Chrome")
        #expect(item.id == "com.google.Chrome")
    }

    @Test func codableRoundTripPreservesValues() throws {
        let item = AppItem(bundleID: "com.apple.Safari", displayName: "Safari")
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(AppItem.self, from: data)
        #expect(decoded == item)
    }

    @Test func equalityIsByValue() {
        let a = AppItem(bundleID: "x", displayName: "X")
        let b = AppItem(bundleID: "x", displayName: "X")
        #expect(a == b)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AppItemTests`
Expected: FAIL — compile error, `cannot find 'AppItem' in scope`.

- [ ] **Step 3: Write minimal implementation**

Delete `Sources/QuickSwitchCore/Placeholder.swift`. Create `Sources/QuickSwitchCore/AppItem.swift`:

```swift
import Foundation

/// An app the user has added to the dock. Immutable; identified by bundle id.
public struct AppItem: Equatable, Identifiable, Codable, Sendable {
    public let bundleID: String
    public let displayName: String

    public init(bundleID: String, displayName: String) {
        self.bundleID = bundleID
        self.displayName = displayName
    }

    public var id: String { bundleID }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AppItemTests`
Expected: PASS — `Executed 3 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSwitchCore/AppItem.swift Tests/QuickSwitchCoreTests/AppItemTests.swift
git rm Sources/QuickSwitchCore/Placeholder.swift
git commit -m "feat: add immutable AppItem model"
```

---

## Task 2: WorkspaceProviding + AppSwitcher

**Files:**
- Create: `Sources/QuickSwitchCore/WorkspaceProviding.swift`
- Create: `Sources/QuickSwitchCore/AppSwitcher.swift`
- Test: `Tests/QuickSwitchCoreTests/AppSwitcherTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/QuickSwitchCoreTests/AppSwitcherTests.swift`:

```swift
import Testing
@testable import QuickSwitchCore

struct AppSwitcherTests {
    final class MockWorkspace: WorkspaceProviding {
        var running: Set<String> = []
        var activateReturn = true
        var launchReturn = true
        private(set) var activatedIDs: [String] = []
        private(set) var launchedIDs: [String] = []

        func isRunning(bundleID: String) -> Bool { running.contains(bundleID) }
        func activate(bundleID: String) -> Bool {
            activatedIDs.append(bundleID); return activateReturn
        }
        func launch(bundleID: String, completion: @escaping (Bool) -> Void) {
            launchedIDs.append(bundleID); completion(launchReturn)
        }
    }

    @Test func runningAppActivatesAndDoesNotLaunch() {
        let mock = MockWorkspace()
        mock.running = ["com.foo.Bar"]
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.switchTo(bundleID: "com.foo.Bar") { result = $0 }

        #expect(result == .activated)
        #expect(mock.activatedIDs == ["com.foo.Bar"])
        #expect(mock.launchedIDs.isEmpty)
    }

    @Test func notRunningAppLaunches() {
        let mock = MockWorkspace()
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.switchTo(bundleID: "com.foo.Bar") { result = $0 }

        #expect(result == .launched)
        #expect(mock.launchedIDs == ["com.foo.Bar"])
        #expect(mock.activatedIDs.isEmpty)
    }

    @Test func activateFailsReturnsFailed() {
        let mock = MockWorkspace()
        mock.running = ["com.foo.Bar"]
        mock.activateReturn = false
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.switchTo(bundleID: "com.foo.Bar") { result = $0 }

        #expect(result == .failed)
    }

    @Test func launchFailsReturnsFailed() {
        let mock = MockWorkspace()
        mock.launchReturn = false
        let switcher = AppSwitcher(workspace: mock)

        var result: AppSwitcher.SwitchResult?
        switcher.switchTo(bundleID: "com.foo.Bar") { result = $0 }

        #expect(result == .failed)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AppSwitcherTests`
Expected: FAIL — `cannot find 'WorkspaceProviding'` / `cannot find 'AppSwitcher'`.

- [ ] **Step 3: Write the protocol and system implementation**

Create `Sources/QuickSwitchCore/WorkspaceProviding.swift`:

```swift
import AppKit

/// Abstraction over the parts of NSWorkspace we use, so AppSwitcher is unit-testable.
public protocol WorkspaceProviding {
    func isRunning(bundleID: String) -> Bool
    func activate(bundleID: String) -> Bool
    func launch(bundleID: String, completion: @escaping (Bool) -> Void)
}

/// Production implementation backed by NSWorkspace / NSRunningApplication.
public struct SystemWorkspace: WorkspaceProviding {
    public init() {}

    public func isRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    public func activate(bundleID: String) -> Bool {
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID).first
        else { return false }
        if #available(macOS 14.0, *) {
            return app.activate()
        } else {
            return app.activate(options: [.activateAllWindows])
        }
    }

    public func launch(bundleID: String, completion: @escaping (Bool) -> Void) {
        guard let url = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleID)
        else { completion(false); return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            completion(error == nil)
        }
    }
}
```

- [ ] **Step 4: Write AppSwitcher**

Create `Sources/QuickSwitchCore/AppSwitcher.swift`:

```swift
import Foundation

/// Decides whether to activate an already-running app or launch it.
public struct AppSwitcher {
    public enum SwitchResult: Equatable {
        case activated
        case launched
        case failed
    }

    private let workspace: WorkspaceProviding

    public init(workspace: WorkspaceProviding) {
        self.workspace = workspace
    }

    public func switchTo(bundleID: String, completion: @escaping (SwitchResult) -> Void) {
        if workspace.isRunning(bundleID: bundleID) {
            let ok = workspace.activate(bundleID: bundleID)
            completion(ok ? .activated : .failed)
        } else {
            workspace.launch(bundleID: bundleID) { ok in
                completion(ok ? .launched : .failed)
            }
        }
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter AppSwitcherTests`
Expected: PASS — `Executed 4 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add Sources/QuickSwitchCore/WorkspaceProviding.swift Sources/QuickSwitchCore/AppSwitcher.swift Tests/QuickSwitchCoreTests/AppSwitcherTests.swift
git commit -m "feat: add WorkspaceProviding protocol and AppSwitcher logic"
```

---

## Task 3: AppListStore (CRUD + persistence)

**Files:**
- Create: `Sources/QuickSwitchCore/AppListStore.swift`
- Test: `Tests/QuickSwitchCoreTests/AppListStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/QuickSwitchCoreTests/AppListStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import QuickSwitchCore

// A reference-type suite so we can tear down in deinit (per the project's Swift testing rule).
// Each test gets a fresh instance with its own unique UserDefaults suite — parallel-safe.
final class AppListStoreTests {
    private let suiteName: String
    private let defaults: UserDefaults

    init() {
        suiteName = "test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func item(_ id: String) -> AppItem {
        AppItem(bundleID: id, displayName: id.uppercased())
    }

    @Test func addAppendsItem() {
        let store = AppListStore(defaults: defaults)
        store.add(item("a"))
        #expect(store.items.map(\.bundleID) == ["a"])
    }

    @Test func addIgnoresDuplicateBundleID() {
        let store = AppListStore(defaults: defaults)
        store.add(item("a"))
        store.add(item("a"))
        #expect(store.items.count == 1)
    }

    @Test func removeDeletesByBundleID() {
        let store = AppListStore(defaults: defaults)
        store.add(item("a"))
        store.add(item("b"))
        store.remove(bundleID: "a")
        #expect(store.items.map(\.bundleID) == ["b"])
    }

    @Test func moveReordersItems() {
        let store = AppListStore(defaults: defaults)
        store.add(item("a"))
        store.add(item("b"))
        store.add(item("c"))
        store.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(store.items.map(\.bundleID) == ["b", "c", "a"])
    }

    @Test func persistenceRoundTripsAcrossInstances() {
        let store1 = AppListStore(defaults: defaults)
        store1.add(item("a"))
        store1.add(item("b"))

        let store2 = AppListStore(defaults: defaults)
        #expect(store2.items.map(\.bundleID) == ["a", "b"])
    }

    @Test func loadSkipsCorruptData() {
        defaults.set(Data("not json".utf8), forKey: "appItems")
        let store = AppListStore(defaults: defaults)
        #expect(store.items.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AppListStoreTests`
Expected: FAIL — `cannot find 'AppListStore' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/QuickSwitchCore/AppListStore.swift`:

```swift
import Foundation
import Combine

/// Single source of truth for the dock's app list. Persists to UserDefaults on every mutation.
public final class AppListStore: ObservableObject {
    @Published public private(set) var items: [AppItem]

    private let defaults: UserDefaults
    private static let key = "appItems"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.items = Self.load(from: defaults)
    }

    public func add(_ item: AppItem) {
        guard !items.contains(where: { $0.bundleID == item.bundleID }) else { return }
        items.append(item)
        persist()
    }

    public func remove(bundleID: String) {
        items.removeAll { $0.bundleID == bundleID }
        persist()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: Self.key)
    }

    private static func load(from defaults: UserDefaults) -> [AppItem] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AppItem].self, from: data)
        else { return [] }
        return decoded
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AppListStoreTests`
Expected: PASS — `Executed 6 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSwitchCore/AppListStore.swift Tests/QuickSwitchCoreTests/AppListStoreTests.swift
git commit -m "feat: add AppListStore with UserDefaults persistence"
```

---

## Task 4: AppResolver (.app URL -> AppItem)

**Files:**
- Create: `Sources/QuickSwitchCore/BundleInfoReading.swift`
- Create: `Sources/QuickSwitchCore/AppResolver.swift`
- Test: `Tests/QuickSwitchCoreTests/AppResolverTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/QuickSwitchCoreTests/AppResolverTests.swift`:

```swift
import Testing
import Foundation
@testable import QuickSwitchCore

struct AppResolverTests {
    struct StubReader: BundleInfoReading {
        let result: (bundleID: String, displayName: String)?
        func readInfo(at url: URL) -> (bundleID: String, displayName: String)? { result }
    }

    @Test func validAppReturnsItem() {
        let reader = StubReader(result: ("com.google.Chrome", "Google Chrome"))
        let resolver = AppResolver(reader: reader)
        let url = URL(fileURLWithPath: "/Applications/Google Chrome.app")

        #expect(resolver.resolve(url: url) == AppItem(bundleID: "com.google.Chrome", displayName: "Google Chrome"))
    }

    @Test func nonAppExtensionReturnsNil() {
        let resolver = AppResolver(reader: StubReader(result: ("com.x", "X")))
        #expect(resolver.resolve(url: URL(fileURLWithPath: "/Users/me/file.txt")) == nil)
    }

    @Test func unreadableBundleReturnsNil() {
        let resolver = AppResolver(reader: StubReader(result: nil))
        #expect(resolver.resolve(url: URL(fileURLWithPath: "/Applications/Broken.app")) == nil)
    }

    @Test func emptyBundleIDReturnsNil() {
        let resolver = AppResolver(reader: StubReader(result: ("", "Nameless")))
        #expect(resolver.resolve(url: URL(fileURLWithPath: "/Applications/Nameless.app")) == nil)
    }

    @Test func systemReaderReadsHandBuiltApp() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("Fake-\(UUID().uuidString).app")
        let contents = tmp.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.example.Fake</string>
            <key>CFBundleName</key>
            <string>Fake App</string>
        </dict>
        </plist>
        """
        try plist.write(to: contents.appendingPathComponent("Info.plist"),
                        atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let info = SystemBundleInfoReader().readInfo(at: tmp)

        #expect(info?.bundleID == "com.example.Fake")
        #expect(info?.displayName == "Fake App")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AppResolverTests`
Expected: FAIL — `cannot find 'BundleInfoReading'` / `cannot find 'AppResolver'`.

- [ ] **Step 3: Write the protocol and system reader**

Create `Sources/QuickSwitchCore/BundleInfoReading.swift`:

```swift
import Foundation

/// Reads identity info out of a `.app` bundle. Injected so AppResolver is unit-testable.
public protocol BundleInfoReading {
    func readInfo(at url: URL) -> (bundleID: String, displayName: String)?
}

/// Production implementation using Foundation's Bundle.
public struct SystemBundleInfoReader: BundleInfoReading {
    public init() {}

    public func readInfo(at url: URL) -> (bundleID: String, displayName: String)? {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier
        else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return (bundleID, name)
    }
}
```

- [ ] **Step 4: Write AppResolver**

Create `Sources/QuickSwitchCore/AppResolver.swift`:

```swift
import Foundation

/// Turns a dropped/picked `.app` URL into an AppItem, rejecting anything invalid.
public struct AppResolver {
    private let reader: BundleInfoReading

    public init(reader: BundleInfoReading = SystemBundleInfoReader()) {
        self.reader = reader
    }

    public func resolve(url: URL) -> AppItem? {
        guard url.pathExtension == "app" else { return nil }
        guard let info = reader.readInfo(at: url), !info.bundleID.isEmpty else { return nil }
        return AppItem(bundleID: info.bundleID, displayName: info.displayName)
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter AppResolverTests`
Expected: PASS — `Executed 5 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add Sources/QuickSwitchCore/BundleInfoReading.swift Sources/QuickSwitchCore/AppResolver.swift Tests/QuickSwitchCoreTests/AppResolverTests.swift
git commit -m "feat: add AppResolver to parse .app bundles into AppItems"
```

---

## Task 5: PreferencesStore

**Files:**
- Create: `Sources/QuickSwitchCore/PreferencesStore.swift`
- Test: `Tests/QuickSwitchCoreTests/PreferencesStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/QuickSwitchCoreTests/PreferencesStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import QuickSwitchCore

final class PreferencesStoreTests {
    private let suiteName: String
    private let defaults: UserDefaults

    init() {
        suiteName = "test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func defaultsAreMediumAndAlwaysOnTop() {
        let prefs = PreferencesStore(defaults: defaults)
        #expect(prefs.iconSize == .medium)
        #expect(prefs.alwaysOnTop)
    }

    @Test func iconSizePersists() {
        let prefs1 = PreferencesStore(defaults: defaults)
        prefs1.iconSize = .large

        let prefs2 = PreferencesStore(defaults: defaults)
        #expect(prefs2.iconSize == .large)
    }

    @Test func alwaysOnTopPersists() {
        let prefs1 = PreferencesStore(defaults: defaults)
        prefs1.alwaysOnTop = false

        let prefs2 = PreferencesStore(defaults: defaults)
        #expect(prefs2.alwaysOnTop == false)
    }

    @Test func iconSizePointsIncreaseWithSize() {
        #expect(IconSize.small.points < IconSize.medium.points)
        #expect(IconSize.medium.points < IconSize.large.points)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PreferencesStoreTests`
Expected: FAIL — `cannot find 'PreferencesStore'` / `cannot find 'IconSize'`.

- [ ] **Step 3: Write the implementation**

Create `Sources/QuickSwitchCore/PreferencesStore.swift`:

```swift
import Foundation
import Combine
import CoreGraphics

public enum IconSize: String, CaseIterable, Codable, Sendable {
    case small, medium, large

    public var points: CGFloat {
        switch self {
        case .small: return 28
        case .medium: return 40
        case .large: return 52
        }
    }
}

/// Global UI preferences. Each property persists to UserDefaults on write.
public final class PreferencesStore: ObservableObject {
    @Published public var iconSize: IconSize {
        didSet { defaults.set(iconSize.rawValue, forKey: Keys.iconSize) }
    }
    @Published public var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop) }
    }

    private enum Keys {
        static let iconSize = "iconSize"
        static let alwaysOnTop = "alwaysOnTop"
    }
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.iconSize = IconSize(rawValue: defaults.string(forKey: Keys.iconSize) ?? "") ?? .medium
        self.alwaysOnTop = (defaults.object(forKey: Keys.alwaysOnTop) as? Bool) ?? true
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PreferencesStoreTests`
Expected: PASS — `Executed 4 tests, with 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add Sources/QuickSwitchCore/PreferencesStore.swift Tests/QuickSwitchCoreTests/PreferencesStoreTests.swift
git commit -m "feat: add PreferencesStore for icon size and always-on-top"
```

---

## Task 6: LoginItemControlling (open-at-login)

**Files:**
- Create: `Sources/QuickSwitchCore/LoginItemControlling.swift`

> System wrapper around `SMAppService` with unavoidable global side effects, so it is validated manually (see Step 3), not unit tested. Views depend on the protocol so they stay testable.

- [ ] **Step 1: Write the protocol and implementation**

Create `Sources/QuickSwitchCore/LoginItemControlling.swift`:

```swift
import Foundation
import ServiceManagement

/// Controls whether the app launches at login. Protocol lets the UI depend on an abstraction.
public protocol LoginItemControlling {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

/// Backed by SMAppService (macOS 13+). Only meaningful when running from a real .app bundle.
@available(macOS 13.0, *)
public struct LoginItemManager: LoginItemControlling {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `swift build`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Note manual verification**

`LoginItemManager` only takes effect when run from the bundled `.app` (Task 10). Verification happens in Task 10, Step 7 (toggle "开机自启", confirm it appears in System Settings ▸ General ▸ Login Items).

- [ ] **Step 4: Commit**

```bash
git add Sources/QuickSwitchCore/LoginItemControlling.swift
git commit -m "feat: add LoginItemControlling wrapper over SMAppService"
```

---

## Task 7: App entry + DockPanel (floating bar appears)

**Files:**
- Modify (replace): `Sources/quickSwitch/main.swift`
- Create: `Sources/quickSwitch/AppDelegate.swift`
- Create: `Sources/quickSwitch/DockPanel.swift`

> UI/system task — verified by running the app and observing, not by unit tests.

- [ ] **Step 1: Write the DockPanel**

Create `Sources/quickSwitch/DockPanel.swift`:

```swift
import AppKit
import SwiftUI
import QuickSwitchCore

/// Borderless, floating, draggable panel that hosts the SwiftUI dock bar.
final class DockPanel: NSPanel {
    init<Content: View>(rootView: Content, alwaysOnTop: Bool) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = alwaysOnTop ? .floating : .normal
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = container
        setContentSize(hosting.fittingSize)
    }

    func setAlwaysOnTop(_ on: Bool) {
        level = on ? .floating : .normal
    }

    func showCentered() {
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = frame.size
            let origin = NSPoint(
                x: frame.midX - self.frame.width / 2,
                y: frame.maxY - self.frame.height - 80
            )
            _ = size
            setFrameOrigin(origin)
        }
        orderFrontRegardless()
    }
}
```

- [ ] **Step 2: Write a temporary placeholder bar to verify the panel**

> `DockBarView` arrives in Task 8. For now, render a stub so the panel is visible.

Create `Sources/quickSwitch/AppDelegate.swift`:

```swift
import AppKit
import SwiftUI
import QuickSwitchCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: DockPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let stub = HStack {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 28))
                .padding(12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        panel = DockPanel(rootView: stub, alwaysOnTop: true)
        panel?.showCentered()
    }
}
```

- [ ] **Step 3: Replace the entry point**

Replace the entire contents of `Sources/quickSwitch/main.swift`:

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // background widget: no Dock icon, no ⌘Tab
app.run()
```

- [ ] **Step 4: Run the app and verify the floating bar**

Run: `swift run quickSwitch`
Expected: A small rounded translucent bar with a grid icon appears near the top-center of the screen, stays above other windows, has no Dock icon, and can be dragged by clicking and holding its background. Press `Ctrl+C` in the terminal to quit.

- [ ] **Step 5: Commit**

```bash
git add Sources/quickSwitch/main.swift Sources/quickSwitch/AppDelegate.swift Sources/quickSwitch/DockPanel.swift
git commit -m "feat: add accessory app entry and floating DockPanel"
```

---

## Task 8: DockBarView + icons + add/remove/reorder/switch

**Files:**
- Create: `Sources/quickSwitch/IconLoader.swift`
- Create: `Sources/quickSwitch/DockIconView.swift`
- Create: `Sources/quickSwitch/DockBarView.swift`
- Modify: `Sources/quickSwitch/AppDelegate.swift`

> UI task — verified by running and interacting.

- [ ] **Step 1: Write the icon loader**

Create `Sources/quickSwitch/IconLoader.swift`:

```swift
import AppKit

/// Fetches an app's current icon by bundle id. Returns nil if the app is not installed.
enum IconLoader {
    static func icon(forBundleID bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
```

- [ ] **Step 2: Write the single-icon view**

Create `Sources/quickSwitch/DockIconView.swift`:

```swift
import SwiftUI
import AppKit
import QuickSwitchCore

/// One dock icon: tap to activate, right-click to remove, shows a fallback when uninstalled.
struct DockIconView: View {
    let item: AppItem
    let size: CGFloat
    let onActivate: () -> Void
    let onRemove: () -> Void

    var body: some View {
        iconImage
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .onTapGesture { onActivate() }
            .help(item.displayName)
            .contextMenu {
                Button("移除 \(item.displayName)", role: .destructive) { onRemove() }
            }
    }

    private var iconImage: Image {
        if let nsImage = IconLoader.icon(forBundleID: item.bundleID) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "questionmark.app.dashed")
    }
}
```

- [ ] **Step 3: Write the bar view (layout, add, reorder, switch)**

Create `Sources/quickSwitch/DockBarView.swift`:

```swift
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import QuickSwitchCore

struct DockBarView: View {
    @ObservedObject var store: AppListStore
    @ObservedObject var prefs: PreferencesStore
    let switcher: AppSwitcher
    let resolver: AppResolver

    @State private var dragging: AppItem?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(store.items) { item in
                DockIconView(
                    item: item,
                    size: prefs.iconSize.points,
                    onActivate: { switcher.switchTo(bundleID: item.bundleID) { _ in } },
                    onRemove: { store.remove(bundleID: item.bundleID) }
                )
                .onDrag {
                    dragging = item
                    return NSItemProvider(object: item.bundleID as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: ReorderDropDelegate(target: item, store: store, dragging: $dragging)
                )
            }
            addButton
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            handleAppDrop(providers)
        }
    }

    private var addButton: some View {
        Button(action: openPicker) {
            Image(systemName: "plus")
                .font(.system(size: prefs.iconSize.points * 0.5, weight: .semibold))
                .frame(width: prefs.iconSize.points, height: prefs.iconSize.points)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("添加应用")
    }

    private func openPicker() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url, let item = resolver.resolve(url: url) {
            store.add(item)
        }
    }

    private func handleAppDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      let item = resolver.resolve(url: url) else { return }
                DispatchQueue.main.async { store.add(item) }
            }
        }
        return accepted
    }
}

/// Reorders items as one is dragged over another.
private struct ReorderDropDelegate: DropDelegate {
    let target: AppItem
    let store: AppListStore
    @Binding var dragging: AppItem?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target,
              let from = store.items.firstIndex(of: dragging),
              let to = store.items.firstIndex(of: target)
        else { return }
        store.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
```

- [ ] **Step 4: Wire the real bar into AppDelegate**

Replace the entire contents of `Sources/quickSwitch/AppDelegate.swift`:

```swift
import AppKit
import SwiftUI
import QuickSwitchCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: DockPanel?

    private let appList = AppListStore()
    private let prefs = PreferencesStore()
    private let switcher = AppSwitcher(workspace: SystemWorkspace())
    private let resolver = AppResolver()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = DockBarView(
            store: appList,
            prefs: prefs,
            switcher: switcher,
            resolver: resolver
        )
        panel = DockPanel(rootView: root, alwaysOnTop: prefs.alwaysOnTop)
        panel?.showCentered()
    }
}
```

- [ ] **Step 5: Run and verify add / switch / remove / reorder**

Run: `swift run quickSwitch`
Expected, in order:
1. An empty bar with just a `+` button appears.
2. Click `+`, pick `/Applications/Safari.app` → Safari's icon appears.
3. Drag `Google Chrome.app` from Finder onto the bar → Chrome's icon appears.
4. Click the Safari icon → Safari comes to the front (launches if not running).
5. Drag one icon over the other → they reorder.
6. Right-click an icon → "移除 …" removes it.
7. Quit with `Ctrl+C`, run again → the same icons are still there (persistence).

- [ ] **Step 6: Commit**

```bash
git add Sources/quickSwitch/IconLoader.swift Sources/quickSwitch/DockIconView.swift Sources/quickSwitch/DockBarView.swift Sources/quickSwitch/AppDelegate.swift
git commit -m "feat: render dock bar with add, switch, remove, and reorder"
```

---

## Task 9: Settings via right-click menu

**Files:**
- Modify: `Sources/quickSwitch/DockBarView.swift`
- Modify: `Sources/quickSwitch/AppDelegate.swift`

> UI task — verified by running and interacting.

- [ ] **Step 1: Add a settings context menu to the bar background**

In `Sources/quickSwitch/DockBarView.swift`, add a stored property for the login-item controller and an `onAlwaysOnTopChange` callback. Change the struct's stored properties to:

```swift
struct DockBarView: View {
    @ObservedObject var store: AppListStore
    @ObservedObject var prefs: PreferencesStore
    let switcher: AppSwitcher
    let resolver: AppResolver
    let loginItem: LoginItemControlling
    let onAlwaysOnTopChange: (Bool) -> Void

    @State private var dragging: AppItem?
    @State private var launchAtLogin: Bool = false
```

Then, on the outer `HStack`, add `.contextMenu { settingsMenu }` immediately after the existing `.background(...)` modifier (before `.onDrop`). Add these members to the struct:

```swift
    @ViewBuilder private var settingsMenu: some View {
        Menu("图标大小") {
            ForEach(IconSize.allCases, id: \.self) { size in
                Button {
                    prefs.iconSize = size
                } label: {
                    Label(label(for: size), systemImage: prefs.iconSize == size ? "checkmark" : "")
                }
            }
        }
        Button {
            prefs.alwaysOnTop.toggle()
            onAlwaysOnTopChange(prefs.alwaysOnTop)
        } label: {
            Label("窗口置顶", systemImage: prefs.alwaysOnTop ? "checkmark" : "")
        }
        Button {
            toggleLaunchAtLogin()
        } label: {
            Label("开机自启", systemImage: launchAtLogin ? "checkmark" : "")
        }
        Divider()
        Button("退出 quickSwitch") { NSApp.terminate(nil) }
    }

    private func label(for size: IconSize) -> String {
        switch size {
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        }
    }

    private func toggleLaunchAtLogin() {
        let next = !launchAtLogin
        do {
            try loginItem.setEnabled(next)
            launchAtLogin = next
        } catch {
            NSSound.beep()
        }
    }
```

Also add `.onAppear { launchAtLogin = loginItem.isEnabled }` to the outer `HStack`.

- [ ] **Step 2: Wire login-item controller + always-on-top into AppDelegate**

Replace the entire contents of `Sources/quickSwitch/AppDelegate.swift`:

```swift
import AppKit
import SwiftUI
import QuickSwitchCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: DockPanel?

    private let appList = AppListStore()
    private let prefs = PreferencesStore()
    private let switcher = AppSwitcher(workspace: SystemWorkspace())
    private let resolver = AppResolver()
    private let loginItem = LoginItemManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = DockBarView(
            store: appList,
            prefs: prefs,
            switcher: switcher,
            resolver: resolver,
            loginItem: loginItem,
            onAlwaysOnTopChange: { [weak self] on in
                self?.panel?.setAlwaysOnTop(on)
            }
        )
        panel = DockPanel(rootView: root, alwaysOnTop: prefs.alwaysOnTop)
        panel?.showCentered()
    }
}
```

- [ ] **Step 3: Run and verify settings**

Run: `swift run quickSwitch`
Expected:
1. Right-click the bar background → a menu shows "图标大小", "窗口置顶", "开机自启", "退出".
2. "图标大小 ▸ 大" → icons grow; reopen menu → "大" has a checkmark; restart app → size persists.
3. Toggle "窗口置顶" off → bar no longer stays above other windows; checkmark reflects state.
4. "退出 quickSwitch" → app quits.

(Open-at-login is verified from the bundled app in Task 10.)

- [ ] **Step 4: Commit**

```bash
git add Sources/quickSwitch/DockBarView.swift Sources/quickSwitch/AppDelegate.swift
git commit -m "feat: add right-click settings menu (icon size, on-top, login, quit)"
```

---

## Task 10: Bundle into a distributable .app + README

**Files:**
- Create: `scripts/bundle.sh`
- Create: `Resources/Info.plist`
- Create: `README.md`

- [ ] **Step 1: Write the Info.plist template**

Create `Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>quickSwitch</string>
    <key>CFBundleDisplayName</key>
    <string>quickSwitch</string>
    <key>CFBundleIdentifier</key>
    <string>com.shiqi.quickSwitch</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>quickSwitch</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: Write the bundling script**

Create `scripts/bundle.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="quickSwitch"
BUILD_DIR=".build/release"
APP_BUNDLE="build/${APP_NAME}.app"

swift build -c release

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Ad-hoc sign so SMAppService (open-at-login) works locally.
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Built ${APP_BUNDLE}"
```

- [ ] **Step 3: Make the script executable**

Run: `chmod +x scripts/bundle.sh`

- [ ] **Step 4: Build the bundle**

Run: `./scripts/bundle.sh`
Expected: ends with `Built build/quickSwitch.app` and no errors.

- [ ] **Step 5: Launch the bundled app**

Run: `open build/quickSwitch.app`
Expected: the floating bar appears with no Dock icon (LSUIElement). Your previously added apps are present.

- [ ] **Step 6: Write the README**

Create `README.md`:

```markdown
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
```

- [ ] **Step 7: Verify open-at-login from the bundled app**

With `build/quickSwitch.app` running: right-click the bar ▸ "开机自启".
Expected: a checkmark appears; the app shows up under System Settings ▸ General ▸ Login Items. Toggle off → it disappears from that list.

- [ ] **Step 8: Run the full test suite once more**

Run: `swift test`
Expected: all tests across `AppItemTests`, `AppSwitcherTests`, `AppListStoreTests`, `AppResolverTests`, `PreferencesStoreTests` PASS.

- [ ] **Step 9: Commit**

```bash
git add scripts/bundle.sh Resources/Info.plist README.md
git commit -m "feat: add .app bundling script, Info.plist, and README"
```

---

## Self-Review

**Spec coverage:**
- §3 core interactions — left-click switch (Task 8), right-click remove (Task 8), drag reorder (Task 8), drop `.app`/`+` add (Task 8), right-click settings (Task 9), drag whole bar (Task 7, `isMovableByWindowBackground`). ✅
- §3 add experience (no bundle id typing) — `AppResolver` auto-reads id+name (Task 4); `IconLoader` auto-reads icon (Task 8). ✅
- §4 tech selection — SwiftPM/SwiftUI+AppKit/NSWorkspace/UserDefaults/SMAppService, no deps (Tasks 0–10). ✅
- §5 modules — every file in the structure maps to a task. ✅
- §6 model immutable + icons fetched live (Task 1, Task 8). ✅
- §7 single-source-of-truth data flow (Task 3 store, wired Tasks 8–9). ✅
- §8 error handling — unreadable/invalid `.app` rejected + beep (Tasks 4, 8, 9); uninstalled app fallback icon (Task 8); corrupt defaults skipped (Task 3). ✅
- §9 no sensitive permissions; LSUIElement + accessory policy (Tasks 7, 10). ✅
- §10 tests — Tasks 1–5 are full TDD; system wrappers (Tasks 6, 7, 8, 9) verified by running, as the spec allows for UI/system layers. ✅
- §11 milestones — map 1:1 to Tasks 0–10. ✅

**Placeholder scan:** No TBD/TODO; every code step contains complete code; every run step states an exact command and expected result. ✅

**Type consistency:** `AppItem(bundleID:displayName:)`, `AppSwitcher.switchTo(bundleID:completion:)` + `SwitchResult`, `AppListStore.add/remove(bundleID:)/move(fromOffsets:toOffset:)`, `AppResolver.resolve(url:)`, `BundleInfoReading.readInfo(at:)`, `PreferencesStore.iconSize/alwaysOnTop` + `IconSize.points`, `LoginItemControlling.isEnabled/setEnabled(_:)`, `DockPanel.setAlwaysOnTop(_:)/showCentered()` — names are consistent across all tasks that reference them. ✅
