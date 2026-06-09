import Foundation

/// One entry in the dock: either an application, or a file/folder shortcut.
public struct AppItem: Equatable, Identifiable, Codable, Sendable {
    /// What activating this entry points at.
    public enum Target: Equatable, Codable, Sendable {
        case app(bundleID: String)
        case path(String) // absolute path to a file or folder
        case url(String)  // web URL (http/https)
    }

    public let target: Target
    public let displayName: String

    public init(target: Target, displayName: String) {
        self.target = target
        self.displayName = displayName
    }

    /// Convenience for an application entry.
    public init(bundleID: String, displayName: String) {
        self.init(target: .app(bundleID: bundleID), displayName: displayName)
    }

    /// Convenience for a file/folder entry.
    public init(path: String, displayName: String) {
        self.init(target: .path(path), displayName: displayName)
    }

    /// Convenience for a web URL entry.
    public init(url: String, displayName: String) {
        self.init(target: .url(url), displayName: displayName)
    }

    /// Stable unique key. Bundle ids, absolute paths and web URLs never collide
    /// (paths begin with "/", web URLs with "http").
    public var id: String {
        switch target {
        case .app(let bundleID): return bundleID
        case .path(let path): return path
        case .url(let url): return url
        }
    }
}
