import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    /// ntfy topic; also the phone-ping channel used when the check-in engine detects AWAY.
    @Published var topic: String {
        didSet { UserDefaults.standard.set(topic, forKey: Keys.topic) }
    }
    /// Minimum gap between local nudges (ACTIVE/STALLING), in minutes. Also used for manual test cadence reference.
    @Published var intervalMinutes: Double {
        didSet { UserDefaults.standard.set(intervalMinutes, forKey: Keys.intervalMinutes) }
    }
    /// Message sent to the phone via ntfy when AWAY is detected.
    @Published var message: String {
        didSet { UserDefaults.standard.set(message, forKey: Keys.message) }
    }
    /// Master switch for the check-in engine.
    @Published var isRunning: Bool {
        didSet { UserDefaults.standard.set(isRunning, forKey: Keys.isRunning) }
    }
    /// Optional animated Dock character. Off by default (pure menubar app).
    @Published var showDockCharacter: Bool {
        didSet { UserDefaults.standard.set(showDockCharacter, forKey: Keys.showDockCharacter) }
    }
    /// Which character to render when the Dock character is on.
    @Published var dockCharacterKind: DockCharacterKind {
        didSet { UserDefaults.standard.set(dockCharacterKind.rawValue, forKey: Keys.dockCharacterKind) }
    }
    /// When true (and a Claude API key is stored), ACTIVE/STALLING local
    /// nudges are generated live by ClaudeDelegate instead of the static
    /// FatigueConfig strings. Falls back to static text automatically if
    /// there's no key or the request fails.
    @Published var useClaudeForNudges: Bool {
        didSet { UserDefaults.standard.set(useClaudeForNudges, forKey: Keys.useClaudeForNudges) }
    }
    /// Lets the buddy roam the whole screen as a small floating window instead
    /// of (or alongside) sitting in the Dock tile. Off by default.
    @Published var enableDesktopPet: Bool {
        didSet { UserDefaults.standard.set(enableDesktopPet, forKey: Keys.enableDesktopPet) }
    }
    @Published var lastPingResult: String = ""

    private enum Keys {
        static let topic = "ntfyTopic"
        static let intervalMinutes = "intervalMinutes"
        static let message = "checkInMessage"
        static let isRunning = "isRunning"
        static let showDockCharacter = "showDockCharacter"
        static let dockCharacterKind = "dockCharacterKind"
        static let useClaudeForNudges = "useClaudeForNudges"
        static let enableDesktopPet = "enableDesktopPet"
    }

    init() {
        let defaults = UserDefaults.standard
        topic = defaults.string(forKey: Keys.topic) ?? ""
        let storedInterval = defaults.double(forKey: Keys.intervalMinutes)
        intervalMinutes = storedInterval > 0 ? storedInterval : 5
        message = defaults.string(forKey: Keys.message) ?? "Still with you — how's it going?"
        isRunning = defaults.bool(forKey: Keys.isRunning)
        showDockCharacter = defaults.bool(forKey: Keys.showDockCharacter)
        dockCharacterKind = DockCharacterKind(rawValue: defaults.string(forKey: Keys.dockCharacterKind) ?? "") ?? .robot
        useClaudeForNudges = defaults.object(forKey: Keys.useClaudeForNudges) as? Bool ?? true
        enableDesktopPet = defaults.bool(forKey: Keys.enableDesktopPet)
    }

    /// Manual "send test ping now" button — bypasses the check-in engine entirely.
    func sendPing() async {
        do {
            try await NtfyClient.send(topic: topic, message: message)
            lastPingResult = "Sent at \(Self.timeFormatter.string(from: Date()))"
        } catch {
            lastPingResult = "Failed: \(error.localizedDescription)"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}
