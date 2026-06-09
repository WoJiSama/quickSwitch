import AppKit
import QuickSwitchCore

/// Fetches the icon for a dock entry — by bundle id for apps, by path for
/// files/folders, and the default browser's icon for web links.
enum IconLoader {
    static func icon(for item: AppItem) -> NSImage? {
        switch item.target {
        case .app(let bundleID):
            guard let url = NSWorkspace.shared
                .urlForApplication(withBundleIdentifier: bundleID)
            else { return nil }
            return NSWorkspace.shared.icon(forFile: url.path)
        case .path(let path):
            return NSWorkspace.shared.icon(forFile: path)
        case .url:
            guard let probe = URL(string: "https://example.com"),
                  let browser = NSWorkspace.shared.urlForApplication(toOpen: probe)
            else { return nil }
            return NSWorkspace.shared.icon(forFile: browser.path)
        }
    }
}
