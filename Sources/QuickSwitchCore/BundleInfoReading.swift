import Foundation

/// Reads identity info out of a `.app` bundle. Injected so AppResolver is unit-testable.
public protocol BundleInfoReading {
    func readInfo(at url: URL) -> (bundleID: String, displayName: String)?
}

/// Production implementation using Foundation's Bundle.
public struct SystemBundleInfoReader: BundleInfoReading {
    public init() {}

    public func readInfo(at url: URL) -> (bundleID: String, displayName: String)? {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier
        else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        return (bundleID, name)
    }
}
