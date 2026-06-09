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

    public func open(_ item: AppItem, completion: @escaping (SwitchResult) -> Void) {
        switch item.target {
        case .app(let bundleID):
            workspace.openApp(bundleID: bundleID) { completion($0 ? .opened : .failed) }
        case .path(let path):
            completion(workspace.open(path: path) ? .opened : .failed)
        case .url(let urlString):
            completion(workspace.openWeb(urlString) ? .opened : .failed)
        }
    }
}
