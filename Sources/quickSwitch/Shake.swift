import SwiftUI

/// Horizontal shake driven by an incrementing trigger; animate the trigger to play it.
struct Shake: GeometryEffect {
    var animatableData: CGFloat
    var amplitude: CGFloat = 6
    var shakes: CGFloat = 3

    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = amplitude * sin(animatableData * .pi * shakes * 2)
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}
