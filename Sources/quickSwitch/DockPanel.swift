import AppKit
import SwiftUI
import QuickSwitchCore

/// Borderless, floating, draggable panel that hosts the SwiftUI dock bar.
final class DockPanel: NSPanel {
    init<Content: View>(rootView: Content, alwaysOnTop: Bool) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 64),
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
        let container = NSView()
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = container
        setContentSize(hosting.fittingSize)
    }

    func setAlwaysOnTop(_ on: Bool) {
        level = on ? .floating : .normal
    }

    func showCentered() {
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = frame.size
            let origin = NSPoint(
                x: frame.midX - self.frame.width / 2,
                y: frame.maxY - self.frame.height - 80
            )
            _ = size
            setFrameOrigin(origin)
        }
        orderFrontRegardless()
    }
}
