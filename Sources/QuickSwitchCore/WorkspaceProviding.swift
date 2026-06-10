import AppKit
import os

private let switchLog = Logger(subsystem: "com.shiqi.quickSwitch", category: "switch")

/// Abstraction over the parts of NSWorkspace we use, so AppSwitcher is unit-testable.
public protocol WorkspaceProviding {
    /// Open an app by bundle id the same way clicking its Dock icon does: activate
    /// and raise a running instance, or launch it if not running.
    func openApp(bundleID: String, completion: @escaping (Bool) -> Void)
    /// Open a file or folder with its default handler. Returns whether it opened.
    func open(path: String) -> Bool
    /// Open a web URL in the default browser. Returns whether it opened.
    func openWeb(_ urlString: String) -> Bool
    /// Whether the app is currently the frontmost (active) application.
    func isFrontmost(bundleID: String) -> Bool
    /// Hide a running app's windows (like clicking its Dock icon when frontmost,
    /// with the hide-on-reclick behavior). Returns whether it was hidden.
    func hideApp(bundleID: String) -> Bool
}

/// Production implementation backed by NSWorkspace.
///
/// App activation uses `openApplication(at:)` (the LaunchServices "open" path that
/// the Dock uses) rather than `NSRunningApplication.activate()`, because the latter
/// marks an app active without reliably raising its windows on macOS 14+.
///
/// Instrumented with os.Logger (subsystem "com.shiqi.quickSwitch", category "switch").
public struct SystemWorkspace: WorkspaceProviding {
    public init() {}

    public func openApp(bundleID: String, completion: @escaping (Bool) -> Void) {
        guard let url = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleID)
        else {
            switchLog.error("openApp \(bundleID, privacy: .public) -> urlForApplication is NIL (unknown to LaunchServices)")
            completion(false)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        switchLog.debug("openApp \(bundleID, privacy: .public) -> openApplication \(url.path, privacy: .private)")
        NSWorkspace.shared.openApplication(at: url, configuration: config) { runningApp, error in
            if let error {
                switchLog.error("openApp \(bundleID, privacy: .public) FAILED: \(error.localizedDescription, privacy: .public)")
            } else {
                switchLog.debug("openApp \(bundleID, privacy: .public) -> ok (\(runningApp?.localizedName ?? "?", privacy: .private))")
            }
            completion(error == nil)
        }
    }

    public func open(path: String) -> Bool {
        let ok = NSWorkspace.shared.open(URL(fileURLWithPath: path))
        switchLog.debug("open path \(path, privacy: .private) -> \(ok)")
        return ok
    }

    public func openWeb(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            switchLog.error("openWeb invalid url: \(urlString, privacy: .private)")
            return false
        }
        let ok = NSWorkspace.shared.open(url)
        switchLog.debug("openWeb \(urlString, privacy: .private) -> \(ok)")
        return ok
    }

    public func isFrontmost(bundleID: String) -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID
    }

    public func hideApp(bundleID: String) -> Bool {
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID).first
        else { return false }
        let ok = app.hide()
        switchLog.debug("hideApp \(bundleID, privacy: .public) -> \(ok)")
        return ok
    }
}
