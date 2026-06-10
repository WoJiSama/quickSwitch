import AppKit
import QuickSwitchCore

/// Fetches the icon for a dock entry, caching by entry id so repeated SwiftUI
/// re-renders (hover, drag, slider changes) don't hit NSWorkspace every frame.
enum IconLoader {
    private static var cache: [String: NSImage] = [:]

    static func icon(for item: AppItem) -> NSImage? {
        if let cached = cache[item.id] { return cached }
        guard let image = resolve(item) else { return nil }
        cache[item.id] = image
        return image
    }

    /// Drop cached icons and availability (e.g. if apps are installed/updated).
    static func invalidate() {
        cache.removeAll()
        availability.removeAll()
    }

    private static func resolve(_ item: AppItem) -> NSImage? {
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

    /// Whether the entry still resolves to something openable (app installed /
    /// file present). Web links are always considered available.
    /// Cached with a short TTL so SwiftUI re-renders (hover, sliders, feedback ticks)
    /// don't hit LaunchServices/FileManager on every frame.
    static func isAvailable(for item: AppItem) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        if let cached = availability[item.id], now - cached.at < availabilityTTL {
            return cached.value
        }
        let value = computeAvailability(item)
        availability[item.id] = (value, now)
        return value
    }

    private static var availability: [String: (value: Bool, at: TimeInterval)] = [:]
    private static let availabilityTTL: TimeInterval = 8

    private static func computeAvailability(_ item: AppItem) -> Bool {
        switch item.target {
        case .app(let bundleID):
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
        case .path(let path):
            return FileManager.default.fileExists(atPath: path)
        case .url:
            return true
        }
    }
}
