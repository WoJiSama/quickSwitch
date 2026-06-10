import AppKit
import SwiftUI
import QuickSwitchCore

/// Borderless, floating panel that hosts the SwiftUI dock bar and drives edge-docking.
final class DockPanel: NSPanel {
    private var edgeDock: EdgeDockController?
    private var didInitialSize = false

    /// Current edge-dock mode (for persistence).
    var edgeMode: EdgeDockController.Mode { edgeDock?.mode ?? .floating }

    init<Content: View>(rootView: Content, alwaysOnTop: Bool,
                        onDropURLs: @escaping ([URL]) -> Bool,
                        onEdgeStateChanged: @escaping () -> Void,
                        onDockStateChanged: @escaping (EdgeDockController.Mode, Bool) -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 96),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = alwaysOnTop ? .floating : .normal
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        // Window moving is handled by WindowDragHandle so it doesn't hijack icon drags.
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hosting = NSHostingView(rootView: rootView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        let container = DropReceivingView()
        container.onDropURLs = onDropURLs
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = container
        setContentSize(hosting.fittingSize)

        let dock = EdgeDockController(panel: self)
        dock.onStateChanged = onEdgeStateChanged
        dock.onDockStateChanged = onDockStateChanged
        edgeDock = dock
    }

    func setAlwaysOnTop(_ on: Bool) {
        level = on ? .floating : .normal
    }

    /// Evaluate edge snapping after a background drag ended (replaces idle polling).
    func evaluateSnap() {
        edgeDock?.evaluateSnapNow()
    }

    /// Rescue path: un-dock if docked, bring the bar back to the main screen center.
    func recenter() {
        edgeDock?.release()
        centerOnScreen()
        orderFrontRegardless()
    }

    /// Keep the window fully visible vertically while allowing horizontal off-screen
    /// travel for edge-docking. Deliberately does NOT call super (which would pull the
    /// window back horizontally and fight the dock-hide).
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let visible = (screen ?? self.screen ?? NSScreen.main)?.visibleFrame else {
            return frameRect
        }
        var rect = frameRect
        if rect.maxY > visible.maxY { rect.origin.y = visible.maxY - rect.height }
        if rect.minY < visible.minY { rect.origin.y = visible.minY }
        return rect
    }

    /// Resize to match the SwiftUI content. Keeps the visible top edge stable,
    /// recenters once on first layout (unless a saved position was restored), and
    /// re-anchors when docked.
    func applyContentSize(_ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let oldTop = frame.maxY
        let oldLeft = frame.minX
        let oldCenterX = frame.midX

        setContentSize(size)

        if edgeMode == .floating {
            var origin = frame.origin
            origin.x = didInitialSize ? oldLeft : (oldCenterX - frame.width / 2)
            origin.y = oldTop - frame.height
            setFrameOrigin(origin)
        } else {
            edgeDock?.reanchor()
        }
        didInitialSize = true
    }

    /// Show the panel, restoring a saved floating position / docked edge if valid.
    func show(restoreOrigin: NSPoint?, edge: EdgeDockController.Mode) {
        if let origin = restoreOrigin, isOnAnyScreen(at: origin) {
            setFrameOrigin(origin)
            didInitialSize = true // preserve the restored origin on first content-size
        } else {
            centerOnScreen()
        }
        orderFrontRegardless()
        edgeDock?.start()
        if edge != .floating { edgeDock?.restore(edge) }
    }

    private func isOnAnyScreen(at origin: NSPoint) -> Bool {
        let test = NSRect(origin: origin, size: frame.size)
        return NSScreen.screens.contains { $0.frame.intersects(test) }
    }

    private func centerOnScreen() {
        guard let vf = NSScreen.main?.visibleFrame else { return }
        setFrameOrigin(NSPoint(x: vf.midX - frame.width / 2, y: vf.maxY - frame.height - 80))
    }
}
