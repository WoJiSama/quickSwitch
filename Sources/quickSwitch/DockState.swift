import SwiftUI

/// Observable mirror of the edge-dock state plus hotkey-driven UI signals, so the
/// SwiftUI bar can render the docked handle, the summon acknowledgment, and the
/// digit badges.
final class DockState: ObservableObject {
    @Published var mode: EdgeDockController.Mode = .floating
    @Published var revealed: Bool = true
    /// Incremented every time the summon hotkey fires (drives the "received" pulse).
    @Published var summonPulse = 0
    /// While true, icons show their ⌥1–9 digit badges.
    @Published var showDigitBadges = false
}
