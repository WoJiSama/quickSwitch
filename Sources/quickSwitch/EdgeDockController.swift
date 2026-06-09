import AppKit

/// Gives the panel edge-docking behaviour:
/// - dropped near the left/right screen edge → snaps and slides off, leaving a thin sliver;
/// - cursor approaches that edge → slides back out; cursor leaves → hides again after a delay;
/// - dropped anywhere else → floats freely.
///
/// Uses a lightweight polling timer over `NSEvent.mouseLocation` /
/// `NSEvent.pressedMouseButtons`, so it needs no Accessibility permission.
final class EdgeDockController {
    enum Mode: Equatable { case floating, left, right }

    private(set) var mode: Mode = .floating { didSet { onDockStateChanged?(mode, revealed) } }

    /// Called when the dock state settles after a drag (snapped to an edge or back to
    /// floating), so the position/edge can be persisted.
    var onStateChanged: (() -> Void)?
    /// Called whenever mode or revealed changes, so the UI can show/hide the handle.
    var onDockStateChanged: ((Mode, Bool) -> Void)?

    private weak var panel: NSPanel?
    private var timer: Timer?

    private var revealed = true { didSet { onDockStateChanged?(mode, revealed) } }
    private var mouseWasDown = false
    private var downOrigin: NSPoint = .zero
    private var downOnWindow = false
    private var didDrag = false
    private var lastInsideAt: TimeInterval = 0

    // Tunables
    private let snapThreshold: CGFloat = 28   // drop within this of an edge → dock
    private let sliver: CGFloat = 6           // visible strip when hidden
    private let revealProximity: CGFloat = 8  // cursor within this of the edge → reveal
    private let dragSlop: CGFloat = 6         // movement above this counts as a drag, not a click
    private let hideDelay: TimeInterval = 0.5
    private let tick: TimeInterval = 0.06

    init(panel: NSPanel) { self.panel = panel }

    func start() {
        let t = Timer(timeInterval: tick, repeats: true) { [weak self] _ in self?.update() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Re-apply the docked frame after the window's content size changes.
    func reanchor() {
        guard mode != .floating else { return }
        applyDockedFrame(animated: false)
    }

    /// Restore a saved docked state at launch (the docked frame is applied by the
    /// next reanchor when the content size is known).
    func restore(_ savedMode: Mode) {
        mode = savedMode
        revealed = (savedMode == .floating)
    }

    private func now() -> TimeInterval { ProcessInfo.processInfo.systemUptime }

    private func update() {
        guard let panel, let screen = panel.screen ?? NSScreen.main else { return }
        let down = (NSEvent.pressedMouseButtons & 0x1) != 0
        let mouse = NSEvent.mouseLocation

        if down && !mouseWasDown {
            mouseWasDown = true
            downOrigin = panel.frame.origin
            didDrag = false
            downOnWindow = panel.frame.contains(mouse) // grabbed the bar itself vs. an external drag
        }

        if down {
            if downOnWindow {
                // User is dragging the bar itself; moving it off the edge un-docks it.
                let moved = abs(panel.frame.origin.x - downOrigin.x) + abs(panel.frame.origin.y - downOrigin.y)
                if moved > dragSlop {
                    didDrag = true
                    if mode != .floating {
                        mode = .floating
                        revealed = true
                    }
                }
            } else if mode != .floating {
                // An external drag-and-drop is in progress (e.g. from the Dock/Finder).
                // If it approaches the docked edge, slide out so the user can drop onto the bar.
                let near = revealZoneContains(mouse, screen: screen)
                    || panel.frame.insetBy(dx: -2, dy: -2).contains(mouse)
                if near {
                    lastInsideAt = now()
                    if !revealed { revealed = true; applyDockedFrame(animated: true) }
                }
            }
            return
        }

        if mouseWasDown {
            mouseWasDown = false
            if didDrag { evaluateSnap(screen: screen) } // a plain click leaves the mode untouched
            return
        }

        guard mode != .floating else { return }

        let inside = revealZoneContains(mouse, screen: screen)
            || panel.frame.insetBy(dx: -2, dy: -2).contains(mouse)
        if inside {
            lastInsideAt = now()
            if !revealed { revealed = true; applyDockedFrame(animated: true) }
        } else if revealed, now() - lastInsideAt > hideDelay {
            revealed = false
            applyDockedFrame(animated: true)
        }
    }

    private func evaluateSnap(screen: NSScreen) {
        guard let panel else { return }
        let vf = screen.visibleFrame
        let f = panel.frame
        if f.minX <= vf.minX + snapThreshold {
            mode = .left; revealed = false; applyDockedFrame(animated: true)
        } else if f.maxX >= vf.maxX - snapThreshold {
            mode = .right; revealed = false; applyDockedFrame(animated: true)
        } else {
            mode = .floating
        }
        onStateChanged?()
    }

    private func revealZoneContains(_ p: NSPoint, screen: NSScreen) -> Bool {
        guard let panel else { return false }
        let vf = screen.visibleFrame
        let f = panel.frame
        guard (f.minY - 6 ... f.maxY + 6).contains(p.y) else { return false }
        switch mode {
        case .left: return p.x <= vf.minX + revealProximity
        case .right: return p.x >= vf.maxX - revealProximity
        case .floating: return false
        }
    }

    private func applyDockedFrame(animated: Bool) {
        guard let panel, let screen = panel.screen ?? NSScreen.main else { return }
        let vf = screen.visibleFrame
        var f = panel.frame
        switch mode {
        case .left:
            f.origin.x = revealed ? vf.minX : vf.minX - (f.width - sliver)
        case .right:
            f.origin.x = revealed ? vf.maxX - f.width : vf.maxX - sliver
        case .floating:
            return
        }
        f.origin.y = min(max(f.origin.y, vf.minY), vf.maxY - f.height)

        if animated && !prefersReducedMotion {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(f, display: true)
            }
        } else {
            panel.setFrame(f, display: true)
        }
    }
}
