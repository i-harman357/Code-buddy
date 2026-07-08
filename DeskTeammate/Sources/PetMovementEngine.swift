import CoreGraphics
import Foundation

/// Pure walk-cycle logic for the roaming desktop pet — no AppKit, no window
/// code, so the "how does he move" behavior is easy to read and tune on its
/// own. PetWindowController owns one of these and asks it for a position
/// every tick.
final class PetMovementEngine {
    private(set) var position: CGPoint
    private(set) var facingRight: Bool = true
    private(set) var isWalking: Bool = false

    private var target: CGPoint
    private var idleUntil: Date = .distantPast
    private var bounds: CGRect

    /// Points per second while walking; caller can bump this for
    /// "STALLING" jitteriness or drop it for a calmer "FLOW" amble.
    var speed: CGFloat = 90

    /// While true, `tick` is a no-op — set while the user is dragging the
    /// character (or has just dropped it) so the walk cycle doesn't fight
    /// the manual position. Cleared by the caller on the next real state
    /// change, which is what makes the walker "resume."
    var isPaused: Bool = false

    init(startingAt point: CGPoint, bounds: CGRect) {
        self.position = point
        self.target = point
        self.bounds = bounds
    }

    func updateBounds(_ newBounds: CGRect) {
        bounds = newBounds
    }

    /// Snap to `point` (e.g. where the user just dropped the character) and
    /// clear any in-flight walk target so the next `tick` after resuming
    /// picks a fresh waypoint instead of continuing an old one.
    func pin(at point: CGPoint) {
        position = point
        target = point
        isWalking = false
    }

    /// Let the walker pick a new waypoint on the very next tick, instead of
    /// waiting out a leftover idle window from before the pause.
    func resume() {
        idleUntil = .distantPast
    }

    /// Advance the walk by `dt` seconds. Call from a repeating timer.
    func tick(dt: TimeInterval) {
        guard !isPaused else { return }
        let now = Date()

        if position == target {
            isWalking = false
            guard now >= idleUntil else { return }
            target = randomWaypoint()
            facingRight = target.x >= position.x
            isWalking = true
            return
        }

        let dx = target.x - position.x
        let dy = target.y - position.y
        let distance = sqrt(dx * dx + dy * dy)
        let step = speed * CGFloat(dt)

        if step >= distance {
            position = target
            isWalking = false
            idleUntil = now.addingTimeInterval(Double.random(in: 2...6))
        } else {
            position.x += dx / distance * step
            position.y += dy / distance * step
        }
    }

    private func randomWaypoint() -> CGPoint {
        let x = CGFloat.random(in: bounds.minX...bounds.maxX)
        return CGPoint(x: x, y: bounds.minY)
    }
}
