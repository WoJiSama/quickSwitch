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
            let hosting = NSHostingController(rootView: SettingsView(prefs: prefs, loginItem: loginItem))
            let window = NSWindow(contentViewController: hosting)
            window.title = "quickSwitch 设置"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.level = .floating
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
