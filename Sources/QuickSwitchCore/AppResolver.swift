import Foundation

/// Turns a dropped/picked `.app` URL into an AppItem, rejecting anything invalid.
public struct AppResolver {
    private let reader: BundleInfoReading

    public init(reader: BundleInfoReading = SystemBundleInfoReader()) {
        self.reader = reader
    }

    public func resolve(url: URL) -> AppItem? {
        guard url.pathExtension == "app" else { return nil }
        guard let info = reader.readInfo(at: url), !info.bundleID.isEmpty else { return nil }
        return AppItem(bundleID: info.bundleID, displayName: info.displayName)
    }
}
