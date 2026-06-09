import Foundation

/// Activates/launches an application entry, or opens a file/folder entry
/// with its default handler.
public struct AppSwitcher {
    public enum SwitchResult: Equatable {
        case activated
        case launched
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
            if workspace.isRunning(bundleID: bundleID) {
                completion(workspace.activate(bundleID: bundleID) ? .activated : .failed)
            } else {
                workspace.launch(bundleID: bundleID) { ok in
                    completion(ok ? .launched : .failed)
                }
            }
        case .path(let path):
            completion(workspace.open(path: path) ? .opened : .failed)
        }
    }
}
