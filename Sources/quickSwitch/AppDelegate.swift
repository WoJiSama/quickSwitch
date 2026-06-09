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
