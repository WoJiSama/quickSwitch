import AppKit
import SwiftUI

/// Lazily creates and shows the in-app user guide window.
final class HelpWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "quickSwitch 使用教程"
            window.isReleasedWhenClosed = false
            window.level = .floating

            let hosting = NSHostingView(rootView: HelpView())
            hosting.autoresizingMask = [.width, .height]
            window.contentView = hosting
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
