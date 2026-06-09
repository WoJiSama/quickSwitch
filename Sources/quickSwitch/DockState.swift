import SwiftUI

/// Observable mirror of the edge-dock state, so the SwiftUI bar can render a
/// high-contrast handle when the bar is docked and hidden.
final class DockState: ObservableObject {
    @Published var mode: EdgeDockController.Mode = .floating
    @Published var revealed: Bool = true
}
