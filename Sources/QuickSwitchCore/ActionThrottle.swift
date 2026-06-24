import Foundation

/// Rate-limits an action so it fires at most once per `minInterval`.
///
/// Used to stop a burst of global-hotkey presses (e.g. holding the digit modifier and
/// mashing the number row) from flooding the main thread with open/activation work,
/// which would otherwise saturate the run loop and freeze the UI. Suppressed calls do
/// NOT advance the window, so a sustained burst still only fires on the leading edge of
/// each interval.
///
/// Pure value type with an injected clock (`now`) so it is fully unit-testable.
public struct ActionThrottle {
    private let minInterval: TimeInterval
    private var lastFire: TimeInterval?

    public init(minInterval: TimeInterval) {
        self.minInterval = minInterval
    }

    /// Whether the action may fire at `now`. Records the time only when it returns true.
    public mutating func shouldFire(now: TimeInterval) -> Bool {
        if let last = lastFire, now - last < minInterval {
            return false
        }
        lastFire = now
        return true
    }
}
