import SwiftUI
import AppKit

/// Transparent background layer for the bar: dragging empty space here moves the
/// whole window. Implemented as a SwiftUI gesture (NOT `isMovableByWindowBackground`
/// and NOT an AppKit `mouseDown` view) so it never steals icon taps/drags — icons
/// sit in front and consume their own events; only empty-area drags reach this gesture.
struct WindowDragHandle: View {
    let windowOrigin: () -> CGPoint
    let moveWindow: (CGPoint) -> Void
    let onMoveEnded: () -> Void

    @State private var start: (mouse: CGPoint, origin: CGPoint)?

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { _ in
                        let mouse = NSEvent.mouseLocation
                        let anchor = start ?? (mouse, windowOrigin())
                        if start == nil { start = anchor }
                        moveWindow(CGPoint(
                            x: anchor.origin.x + (mouse.x - anchor.mouse.x),
                            y: anchor.origin.y + (mouse.y - anchor.mouse.y)
                        ))
                    }
                    .onEnded { _ in
                        start = nil
                        onMoveEnded()
                    }
            )
    }
}
