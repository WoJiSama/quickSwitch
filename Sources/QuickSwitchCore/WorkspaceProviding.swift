import AppKit
import os

private let switchLog = Logger(subsystem: "com.shiqi.quickSwitch", category: "switch")

/// Abstraction over the parts of NSWorkspace we use, so AppSwitcher is unit-testable.
public protocol WorkspaceProviding {
    func isRunning(bundleID: String) -> Bool
    func activate(bundleID: String) -> Bool
    func launch(bundleID: String, completion: @escaping (Bool) -> Void)
    /// Open a file or folder with its default handler. Returns whether it opened.
    func open(path: String) -> Bool
    /// Open a web URL in the default browser. Returns whether it opened.
    func openWeb(_ urlString: String) -> Bool
}

/// Production implementation backed by NSWorkspace / NSRunningApplication.
/// Instrumented with os.Logger (subsystem "com.shiqi.quickSwitch", category "switch")
/// so switch failures can be diagnosed via Console / `log stream`.
public struct SystemWorkspace: WorkspaceProviding {
    public init() {}

    public func isRunning(bundleID: String) -> Bool {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        switchLog.info("isRunning \(bundleID, privacy: .public) -> \(apps.count) instance(s)")
        return !apps.isEmpty
    }

    public func activate(bundleID: String) -> Bool {
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID).first
        else {
            switchLog.error("activate \(bundleID, privacy: .public) -> NO running instance")
            return false
        }
        let ok: Bool
        if #available(macOS 14.0, *) {
            ok = app.activate()
        } else {
            ok = app.activate(options: [.activateAllWindows])
        }
        switchLog.info("""
        activate \(bundleID, privacy: .public) -> \(ok) \
        (name=\(app.localizedName ?? "?", privacy: .public), \
        hidden=\(app.isHidden), active=\(app.isActive), \
        policy=\(app.activationPolicy.rawValue))
        """)
        return ok
    }

    public func launch(bundleID: String, completion: @escaping (Bool) -> Void) {
        guard let url = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleID)
        else {
            switchLog.error("launch \(bundleID, privacy: .public) -> urlForApplication is NIL (unknown to LaunchServices)")
            completion(false)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        switchLog.info("launch \(bundleID, privacy: .public) -> opening \(url.path, privacy: .public)")
        NSWorkspace.shared.openApplication(at: url, configuration: config) { runningApp, error in
            if let error {
                switchLog.error("launch \(bundleID, privacy: .public) FAILED: \(error.localizedDescription, privacy: .public)")
            } else {
                switchLog.info("launch \(bundleID, privacy: .public) -> ok (\(runningApp?.localizedName ?? "?", privacy: .public))")
            }
            completion(error == nil)
        }
    }

    public func open(path: String) -> Bool {
        let ok = NSWorkspace.shared.open(URL(fileURLWithPath: path))
        switchLog.info("open path \(path, privacy: .public) -> \(ok)")
        return ok
    }

    public func openWeb(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            switchLog.error("openWeb invalid url: \(urlString, privacy: .public)")
            return false
        }
        let ok = NSWorkspace.shared.open(url)
        switchLog.info("openWeb \(urlString, privacy: .public) -> \(ok)")
        return ok
    }
}
