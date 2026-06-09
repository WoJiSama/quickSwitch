import AppKit
import SwiftUI
import Combine
import QuickSwitchCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: DockPanel?
    private var cancellables: Set<AnyCancellable> = []

    private let appList = AppListStore()
    private let prefs = PreferencesStore()
    private let feedback = FeedbackCenter()
    private let switcher = AppSwitcher(workspace: SystemWorkspace())
    private let resolver = AppResolver()
    private let loginItem = LoginItemManager()
    private let hoverName = HoverNameController()
    private lazy var settings = SettingsWindowController(prefs: prefs, loginItem: loginItem)
    private let help = HelpWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = DockBarView(
            store: appList,
            prefs: prefs,
            feedback: feedback,
            switcher: switcher,
            resolver: resolver,
            onResize: { [weak self] size in self?.panel?.applyContentSize(size) },
            windowOrigin: { [weak self] in self?.panel?.frame.origin ?? .zero },
            moveWindow: { [weak self] origin in self?.panel?.setFrameOrigin(origin) },
            onOpenSettings: { [weak self] in self?.settings.show() },
            onOpenHelp: { [weak self] in self?.help.show() },
            showHoverName: { [weak self] name in
                if let name { self?.hoverName.show(name) } else { self?.hoverName.hide() }
            }
        )
        panel = DockPanel(
            rootView: root,
            alwaysOnTop: prefs.alwaysOnTop,
            onDropURLs: { [weak self] urls in
                guard let self else { return false }
                var added = false
                for url in urls where addItem(from: url, resolver: self.resolver, store: self.appList, feedback: self.feedback) {
                    added = true
                }
                return added
            }
        )
        panel?.showCentered()

        // Apply always-on-top changes from anywhere (menu or Settings window).
        prefs.$alwaysOnTop
            .sink { [weak self] on in self?.panel?.setAlwaysOnTop(on) }
            .store(in: &cancellables)
    }
}
