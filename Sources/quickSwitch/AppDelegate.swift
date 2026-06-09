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
            },
            onResize: { [weak self] size in
                self?.panel?.applyContentSize(size)
            }
        )
        panel = DockPanel(rootView: root, alwaysOnTop: prefs.alwaysOnTop)
        panel?.showCentered()
    }
}
