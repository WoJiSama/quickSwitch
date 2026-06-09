import AppKit
import SwiftUI
import QuickSwitchCore

/// Borderless, floating, draggable panel that hosts the SwiftUI dock bar
/// and drives edge-docking auto-hide.
final class DockPanel: NSPanel {
    private var edgeDock: EdgeDockController?
    private var didInitialSize = false

    init<Content: View>(rootView: Content, alwaysOnTop: Bool, onDropURLs: @escaping ([URL]) -> Bool) {
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
        isMovableByWindowBackground = true
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
        edgeDock = EdgeDockController(panel: self)
    }

    func setAlwaysOnTop(_ on: Bool) {
        level = on ? .floating : .normal
    }

    /// Resize the window to match the SwiftUI content. Keeps the visible top edge
    /// stable, recenters once on first layout, and re-anchors when docked.
    func applyContentSize(_ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let oldTop = frame.maxY
        let oldLeft = frame.minX
        let oldCenterX = frame.midX

        setContentSize(size)

        if edgeDock?.mode == .floating || edgeDock == nil {
            var origin = frame.origin
            origin.x = didInitialSize ? oldLeft : (oldCenterX - frame.width / 2)
            origin.y = oldTop - frame.height
            setFrameOrigin(origin)
        } else {
            edgeDock?.reanchor()
        }
        didInitialSize = true
    }

    func showCentered() {
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            setFrameOrigin(NSPoint(x: vf.midX - frame.width / 2, y: vf.maxY - frame.height - 80))
        }
        orderFrontRegardless()
        edgeDock?.start()
    }
}
