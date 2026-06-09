import Foundation

/// Turns a dropped/picked URL into an AppItem:
/// - a `.app` bundle becomes an application entry (reads its bundle id);
/// - any other existing file or folder becomes a path entry;
/// - an http/https URL becomes a web entry.
public struct AppResolver {
    private let reader: BundleInfoReading
    private let fileManager: FileManager

    public init(reader: BundleInfoReading = SystemBundleInfoReader(),
                fileManager: FileManager = .default) {
        self.reader = reader
        self.fileManager = fileManager
    }

    public func resolve(url: URL) -> AppItem? {
        if url.isFileURL {
            if url.pathExtension == "app" {
                guard let info = reader.readInfo(at: url), !info.bundleID.isEmpty else { return nil }
                return AppItem(target: .app(bundleID: info.bundleID), displayName: info.displayName)
            }
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return AppItem(target: .path(url.path), displayName: url.lastPathComponent)
        }

        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        let name = url.host ?? url.absoluteString
        return AppItem(target: .url(url.absoluteString), displayName: name)
    }
}
