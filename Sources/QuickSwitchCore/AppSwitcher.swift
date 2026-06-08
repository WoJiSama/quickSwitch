import Foundation

/// Decides whether to activate an already-running app or launch it.
public struct AppSwitcher {
    public enum SwitchResult: Equatable {
        case activated
        case launched
        case failed
    }

    private let workspace: WorkspaceProviding

    public init(workspace: WorkspaceProviding) {
        self.workspace = workspace
    }

    public func switchTo(bundleID: String, completion: @escaping (SwitchResult) -> Void) {
        if workspace.isRunning(bundleID: bundleID) {
            let ok = workspace.activate(bundleID: bundleID)
            completion(ok ? .activated : .failed)
        } else {
            workspace.launch(bundleID: bundleID) { ok in
                completion(ok ? .launched : .failed)
            }
        }
    }
}
