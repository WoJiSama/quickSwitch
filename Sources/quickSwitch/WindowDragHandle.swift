import SwiftUI
import AppKit

/// A transparent background layer that moves the whole window when the user drags
/// empty space on the bar — WITHOUT `isMovableByWindowBackground`, which would also
/// hijack icon reorder-drags. Icons sit in front of this and handle their own drags;
/// only presses that fall through to this background move the window.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragNSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragNSView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
