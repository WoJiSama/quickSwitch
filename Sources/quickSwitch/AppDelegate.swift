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

    private enum WinKeys {
        static let originX = "win.originX"
        static let originY = "win.originY"
        static let hasPosition = "win.hasPosition"
        static let edge = "win.edge"
    }

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
            },
            onMoveEnded: { [weak self] in self?.saveWindowState() }
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
            },
            onEdgeStateChanged: { [weak self] in self?.saveWindowState() }
        )

        let saved = savedWindowState()
        panel?.show(restoreOrigin: saved.origin, edge: saved.edge)

        prefs.$alwaysOnTop
            .sink { [weak self] on in self?.panel?.setAlwaysOnTop(on) }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveWindowState()
    }

    // MARK: - Window state persistence

    private func saveWindowState() {
        guard let panel else { return }
        let defaults = UserDefaults.standard
        let origin = panel.frame.origin
        defaults.set(Double(origin.x), forKey: WinKeys.originX)
        defaults.set(Double(origin.y), forKey: WinKeys.originY)
        defaults.set(true, forKey: WinKeys.hasPosition)
        defaults.set(edgeString(panel.edgeMode), forKey: WinKeys.edge)
    }

    private func savedWindowState() -> (origin: NSPoint?, edge: EdgeDockController.Mode) {
        let defaults = UserDefaults.standard
        let origin: NSPoint? = defaults.bool(forKey: WinKeys.hasPosition)
            ? NSPoint(x: defaults.double(forKey: WinKeys.originX), y: defaults.double(forKey: WinKeys.originY))
            : nil
        return (origin, edgeMode(defaults.string(forKey: WinKeys.edge) ?? "floating"))
    }

    private func edgeString(_ mode: EdgeDockController.Mode) -> String {
        switch mode {
        case .left: return "left"
        case .right: return "right"
        case .floating: return "floating"
        }
    }

    private func edgeMode(_ string: String) -> EdgeDockController.Mode {
        switch string {
        case "left": return .left
        case "right": return .right
        default: return .floating
        }
    }
}
