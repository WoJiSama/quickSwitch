import AppKit

/// Fetches an app's current icon by bundle id. Returns nil if the app is not installed.
enum IconLoader {
    static func icon(forBundleID bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
