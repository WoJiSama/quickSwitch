import AppKit
import SwiftUI
import QuickSwitchCore

/// Lazily creates and shows the Settings window (a normal titled window hosting
/// `SettingsView`). The app is an accessory, so we briefly activate it so the
/// window can take focus for the sliders.
final class SettingsWindowController {
    private var window: NSWindow?
    private let prefs: PreferencesStore
    private let loginItem: LoginItemControlling

    init(prefs: PreferencesStore, loginItem: LoginItemControlling) {
        self.prefs = prefs
        self.loginItem = loginItem
    }

    func show() {
        if window == nil {
            // Explicit content size — relying on the SwiftUI hosting controller to
            // report a size can collapse the window to just its title bar.
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "quickSwitch 设置"
            window.isReleasedWhenClosed = false
            window.level = .floating

            let hosting = NSHostingView(rootView: SettingsView(prefs: prefs, loginItem: loginItem))
            hosting.autoresizingMask = [.width, .height]
            window.contentView = hosting
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
