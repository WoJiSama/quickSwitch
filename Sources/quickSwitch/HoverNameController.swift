import AppKit
import SwiftUI

/// A tiny floating tooltip window that shows the hovered icon's name near the cursor.
/// Lives outside the dock window, so it works in any orientation, never clips, and
/// doesn't interfere with the edge-hide sliver. Ignores mouse events.
final class HoverNameController {
    private let panel: NSPanel
    private let hosting: NSHostingView<HoverLabel>
    private var hideWork: DispatchWorkItem?

    init() {
        hosting = NSHostingView(rootView: HoverLabel(text: ""))
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 20, height: 20),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = hosting
    }

    /// Show (or update) the tooltip with `name`, positioned near the cursor.
    func show(_ name: String) {
        hideWork?.cancel()
        hosting.rootView = HoverLabel(text: name)
        panel.setContentSize(hosting.fittingSize)
        positionNearCursor()
        panel.orderFrontRegardless()
    }

    /// Hide, with a small debounce so moving between adjacent icons doesn't flicker.
    func hide() {
        let work = DispatchWorkItem { [weak self] in self?.panel.orderOut(nil) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07, execute: work)
    }

    private func positionNearCursor() {
        let mouse = NSEvent.mouseLocation
        let size = panel.frame.size
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let vf = screen?.visibleFrame ?? .zero

        var x = mouse.x - size.width / 2
        var y = mouse.y + 20 // above the cursor
        if y + size.height > vf.maxY { y = mouse.y - size.height - 20 } // flip below near top
        x = min(max(x, vf.minX + 4), vf.maxX - size.width - 4)
        y = min(max(y, vf.minY + 4), vf.maxY - size.height - 4)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct HoverLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
            .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
            .padding(5) // leave room inside the panel for the shadow
    }
}
