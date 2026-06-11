import AppKit

/// Gives the panel edge-docking behaviour:
/// - dropped near the left/right screen edge → snaps and slides off, leaving a thin sliver;
/// - cursor approaches that edge → slides back out; cursor leaves → hides again after a delay;
/// - dropped anywhere else → floats freely.
///
/// While DOCKED it runs a lightweight polling timer over `NSEvent.mouseLocation` /
/// `NSEvent.pressedMouseButtons` (no Accessibility permission needed). While FLOATING
/// the timer is stopped entirely — snap evaluation is driven by the window-drag
/// gesture's end via `evaluateSnapNow()` — so an idle floating bar costs nothing.
final class EdgeDockController {
    enum Mode: Equatable { case floating, left, right }

    private(set) var mode: Mode = .floating {
        didSet {
            onDockStateChanged?(mode, revealed)
            syncTimer()
        }
    }

    /// Called when the dock state settles after a drag (snapped to an edge or back to
    /// floating), so the position/edge can be persisted.
    var onStateChanged: (() -> Void)?
    /// Called whenever mode or revealed changes, so the UI can show/hide the handle.
    var onDockStateChanged: ((Mode, Bool) -> Void)?

    private weak var panel: NSPanel?
    private var timer: Timer?

    private var revealed = true { didSet { onDockStateChanged?(mode, revealed) } }
    /// When true (digit-selection mode), the docked bar stays revealed and won't auto-hide.
    private var forceReveal = false
    private var mouseWasDown = false
    private var downOrigin: NSPoint = .zero
    private var downOnWindow = false
    private var didDrag = false
    private var lastInsideAt: TimeInterval = 0

    // Tunables
    private let snapThreshold: CGFloat = 28    // drop within this of an edge → dock
    private let sliver: CGFloat = 6            // visible strip when hidden
    private let revealProximity: CGFloat = 8   // cursor within this of the edge → reveal
    private let dragSlop: CGFloat = 6          // movement above this counts as a drag, not a click
    private let hideDelay: TimeInterval = 0.5
    private let tick: TimeInterval = 0.06
    private let revealDuration: TimeInterval = 0.12
    private let hideDuration: TimeInterval = 0.18

    init(panel: NSPanel) { self.panel = panel }

    /// Ensure the timer matches the current mode (it only runs while docked).
    func start() { syncTimer() }

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

    /// Evaluate snapping after a window drag ended (called from the drag gesture's
    /// end, so no polling is needed while floating).
    func evaluateSnapNow() {
        guard let panel, let screen = panel.screen ?? NSScreen.main else { return }
        evaluateSnap(screen: screen)
    }

    /// Un-dock and return to floating (rescue path, e.g. from the menu bar icon).
    func release() {
        guard mode != .floating else { return }
        mode = .floating
        revealed = true
        onStateChanged?()
    }

    /// Hotkey toggle while docked: slide out (and stay out for a grace period even
    /// though the cursor isn't nearby), or slide back in.
    /// Digit-selection mode: keep a docked bar slid out (and don't auto-hide) while on.
    func setForceReveal(_ on: Bool) {
        forceReveal = on
        guard mode != .floating else { return }
        if on {
            revealed = true
            applyDockedFrame(animated: true)
        } else {
            lastInsideAt = now() // let the normal hide-delay run from now
        }
    }

    func toggleReveal(grace: TimeInterval = 2.5) {
        guard mode != .floating else { return }
        if revealed {
            revealed = false
        } else {
            revealed = true
            lastInsideAt = now() + grace // keeps it out past the usual hide delay
        }
        applyDockedFrame(animated: true)
    }

    private func syncTimer() {
        if mode == .floating {
            stop()
        } else if timer == nil {
            mouseWasDown = false
            didDrag = false
            let t = Timer(timeInterval: tick, repeats: true) { [weak self] _ in self?.update() }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }

    private func now() -> TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// Runs only while docked.
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
                // User is dragging the docked bar; moving it un-docks it (the drag
                // gesture's end will then re-evaluate snapping).
                let moved = abs(panel.frame.origin.x - downOrigin.x) + abs(panel.frame.origin.y - downOrigin.y)
                if moved > dragSlop {
                    didDrag = true
                    mode = .floating // stops this timer via syncTimer
                    revealed = true
                }
            } else {
                // An external drag-and-drop is in progress (e.g. from Finder).
                // If it approaches the docked edge, slide out so the user can drop.
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
            return
        }

        let inside = revealZoneContains(mouse, screen: screen)
            || panel.frame.insetBy(dx: -2, dy: -2).contains(mouse)
        if inside {
            lastInsideAt = now()
            if !revealed { revealed = true; applyDockedFrame(animated: true) }
        } else if revealed, !forceReveal, now() - lastInsideAt > hideDelay {
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
        // Generous vertical band so users don't have to hit the sliver pixel-perfectly.
        let pad = max(40, f.height * 0.75)
        guard (f.minY - pad ... f.maxY + pad).contains(p.y) else { return false }
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
                ctx.duration = revealed ? revealDuration : hideDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(f, display: true)
            }
        } else {
            panel.setFrame(f, display: true)
        }
    }
}
