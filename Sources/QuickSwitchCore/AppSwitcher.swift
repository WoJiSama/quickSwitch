import Foundation

/// Opens a dock entry: an app (activate/launch like the Dock), or a file/folder/web
/// URL via its default handler.
public struct AppSwitcher {
    public enum SwitchResult: Equatable {
        case opened
        case failed
    }

    private let workspace: WorkspaceProviding

    public init(workspace: WorkspaceProviding) {
        self.workspace = workspace
    }

    /// Open the entry. For app entries, if `hideIfFrontmost` is set and the app is
    /// already frontmost, hide it instead (Dock-like A↔B toggling).
    public func open(_ item: AppItem, hideIfFrontmost: Bool = false,
                     completion: @escaping (SwitchResult) -> Void) {
        switch item.target {
        case .app(let bundleID):
            if hideIfFrontmost, workspace.isFrontmost(bundleID: bundleID) {
                completion(workspace.hideApp(bundleID: bundleID) ? .opened : .failed)
                return
            }
            workspace.openApp(bundleID: bundleID) { completion($0 ? .opened : .failed) }
        case .path(let path):
            workspace.open(path: path) { completion($0 ? .opened : .failed) }
        case .url(let urlString):
            workspace.openWeb(urlString) { completion($0 ? .opened : .failed) }
        }
    }
}
