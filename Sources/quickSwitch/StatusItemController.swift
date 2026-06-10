import AppKit

/// Menu-bar fallback entry point — the standard pattern for LSUIElement widgets.
/// Guarantees Settings / Help / Quit stay reachable even if the user never discovers
/// right-click, and offers a rescue action when the bar is lost (off-screen/docked).
final class StatusItemController: NSObject {
    private var statusItem: NSStatusItem?
    private let onOpenSettings: () -> Void
    private let onOpenHelp: () -> Void
    private let onRecenter: () -> Void

    init(onOpenSettings: @escaping () -> Void,
         onOpenHelp: @escaping () -> Void,
         onRecenter: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        self.onOpenHelp = onOpenHelp
        self.onRecenter = onRecenter
    }

    func setVisible(_ visible: Bool) {
        if visible {
            show()
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func show() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // Explicit symbol configuration + template mode: without these the symbol is
        // rasterized at its tiny default size and upscaled (blurry), and wouldn't
        // adapt to the menu bar's light/dark appearance.
        let image = NSImage(
            systemSymbolName: "square.grid.2x2",
            accessibilityDescription: "quickSwitch"
        )?.withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
        image?.isTemplate = true
        item.button?.image = image

        let menu = NSMenu()
        menu.addItem(menuItem(title: "把快捷条移回屏幕中央", action: #selector(recenter)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "设置…", action: #selector(openSettings)))
        menu.addItem(menuItem(title: "使用教程", action: #selector(openHelp)))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 quickSwitch",
                              action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    private func menuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openSettings() { onOpenSettings() }
    @objc private func openHelp() { onOpenHelp() }
    @objc private func recenter() { onRecenter() }
}
