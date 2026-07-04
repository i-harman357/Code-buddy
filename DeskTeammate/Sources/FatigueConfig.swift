import Foundation

/// All check-in engine thresholds in one place. Tune here.
enum FatigueConfig {
    // MARK: - Polling
    static let pollIntervalSeconds: TimeInterval = 5

    // MARK: - AWAY
    /// Idle time (no keyboard/mouse input) before we consider you away.
    static let awayIdleThresholdSeconds: TimeInterval = 10 * 60

    // MARK: - FLOW
    /// Steady on the same frontmost app for at least this long...
    static let flowMinSameAppSeconds: TimeInterval = 10 * 60
    /// ...and input seen within this recently = FLOW (quiet).
    static let flowMaxInputAgeSeconds: TimeInterval = 2 * 60

    // MARK: - STALLING (rapid app switching)
    /// Window over which we count frontmost-app switches.
    static let switchWindowSeconds: TimeInterval = 5 * 60
    /// Switches within that window at/above this count = STALLING.
    static let switchCountThreshold: Int = 4

    // MARK: - STALLING (long session + late hour)
    static let longSessionThresholdSeconds: TimeInterval = 90 * 60
    /// Hours (0-23, in device local time) considered "late night."
    static let lateNightStartHour: Int = 23
    static let lateNightEndHour: Int = 5 // exclusive upper bound, wraps past midnight

    // MARK: - Nudge messages (ACTIVE / STALLING; AWAY message is user-configurable)
    static let activeNudgeMessage = "Still with you. Quick check-in."
    static let stallingNudgeMessage = "You've been jumping around a bit — want to reset on one thing?"
}
