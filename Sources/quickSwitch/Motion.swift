import SwiftUI
import AppKit

/// Whether the system "Reduce Motion" accessibility setting is enabled.
var prefersReducedMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
}

/// Run `body`, animating with `animation` — unless Reduce Motion is on, in which
/// case the change is applied instantly. Keeps every animation honoring the setting.
@discardableResult
func withMotion<Result>(_ animation: Animation, _ body: () -> Result) -> Result {
    if prefersReducedMotion {
        return body()
    }
    return withAnimation(animation, body)
}
