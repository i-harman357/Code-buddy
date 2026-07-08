import Foundation

/// Static line pools for the Deadpool overlay's speech bubble, keyed to
/// CheckInState. Kept separate from PetWindowController so the voice can be
/// tuned without touching window/animation code.
enum DeadpoolLines {
    static let greeting = "Wade Wilson reporting for duty. Let's get this bread."

    private static let flow = [
        "Okay okay, you're focused. I'll just... stand here.",
        "Flow state. Respect. I'll save my commentary.",
        "Look at you go. Almost makes me proud.",
    ]

    private static let active = [
        "Still alive over there?",
        "You good? Blink twice if you need help.",
        "Productivity: confirmed. You're welcome.",
    ]

    private static let stalling = [
        "Bro. BRRRO. Pick an app and commit.",
        "You've switched tabs more times than I've broken the fourth wall.",
        "This is painful to watch. And I've been shot. Multiple times.",
        "One. Task. That's all I'm asking.",
    ]

    /// "[X]" gets swapped for elapsed-away minutes by `resolveAway`.
    private static let away = [
        "...Hello? Did you die? Should I call someone?",
        "The keyboard misses you. I miss you. Don't tell anyone.",
        "Gone for [X] minutes. I've fought Thanos in less time.",
    ]

    private static func pool(for state: CheckInState) -> [String] {
        switch state {
        case .flow: return flow
        case .active: return active
        case .stalling: return stalling
        case .away: return away
        case .stopped: return []
        }
    }

    /// Random line from `state`'s pool, avoiding an immediate repeat of
    /// `excluding` when the pool has more than one option. Returns nil for
    /// states with no pool (STOPPED).
    static func pick(for state: CheckInState, excluding: String?) -> String? {
        let candidates = pool(for: state)
        guard !candidates.isEmpty else { return nil }
        guard candidates.count > 1 else { return candidates[0] }

        var choice = candidates.randomElement()!
        var attempts = 0
        while choice == excluding && attempts < 10 {
            choice = candidates.randomElement()!
            attempts += 1
        }
        return choice
    }

    static func resolveAway(_ line: String, minutes: Int) -> String {
        line.replacingOccurrences(of: "[X]", with: "\(max(minutes, 1))")
    }
}
