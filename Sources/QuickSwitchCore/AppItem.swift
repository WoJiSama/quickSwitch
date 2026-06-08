import Foundation

/// An app the user has added to the dock. Immutable; identified by bundle id.
public struct AppItem: Equatable, Identifiable, Codable, Sendable {
    public let bundleID: String
    public let displayName: String

    public init(bundleID: String, displayName: String) {
        self.bundleID = bundleID
        self.displayName = displayName
    }

    public var id: String { bundleID }
}
