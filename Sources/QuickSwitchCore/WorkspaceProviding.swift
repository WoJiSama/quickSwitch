import AppKit

/// Abstraction over the parts of NSWorkspace we use, so AppSwitcher is unit-testable.
public protocol WorkspaceProviding {
    func isRunning(bundleID: String) -> Bool
    func activate(bundleID: String) -> Bool
    func launch(bundleID: String, completion: @escaping (Bool) -> Void)
    /// Open a file or folder with its default handler. Returns whether it opened.
    func open(path: String) -> Bool
}

/// Production implementation backed by NSWorkspace / NSRunningApplication.
public struct SystemWorkspace: WorkspaceProviding {
    public init() {}

    public func isRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    public func activate(bundleID: String) -> Bool {
        guard let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID).first
        else { return false }
        if #available(macOS 14.0, *) {
            return app.activate()
        } else {
            return app.activate(options: [.activateAllWindows])
        }
    }

    public func launch(bundleID: String, completion: @escaping (Bool) -> Void) {
        guard let url = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleID)
        else { completion(false); return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            completion(error == nil)
        }
    }

    public func open(path: String) -> Bool {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}
