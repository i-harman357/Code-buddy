import Foundation
import Combine
import AppKit
import CoreGraphics

enum CheckInState: String {
    case stopped = "STOPPED"
    case flow = "FLOW"
    case active = "ACTIVE"
    case stalling = "STALLING"
    case away = "AWAY"
}

@MainActor
final class CheckInEngine: ObservableObject {
    // Visible state
    @Published private(set) var state: CheckInState = .stopped

    // Debug signal values, shown in the popover
    @Published private(set) var idleSeconds: TimeInterval = 0
    @Published private(set) var frontmostAppName: String = "-"
    @Published private(set) var appStreakSeconds: TimeInterval = 0
    @Published private(set) var switchCountInWindow: Int = 0
    @Published private(set) var sessionSeconds: TimeInterval = 0
    @Published private(set) var isLateNight: Bool = false
    @Published private(set) var lastNudgeAt: Date?
    @Published private(set) var lastAwayPingAt: Date?

    private let appState: AppState
    private var timer: Timer?
    private var subscription: AnyCancellable?

    private var sessionStart = Date()
    private var appStreakStart = Date()
    private var lastAppName: String?
    private var switchTimestamps: [Date] = []
    private var awayPingSentForCurrentPeriod = false

    init(appState: AppState) {
        self.appState = appState
        subscription = appState.$isRunning
            .sink { [weak self] running in
                running ? self?.start() : self?.stop()
            }
        if appState.isRunning { start() }
    }

    private func start() {
        resetCounters()
        state = .active
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: FatigueConfig.pollIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        state = .stopped
    }

    private func resetCounters() {
        let now = Date()
        sessionStart = now
        appStreakStart = now
        lastAppName = NSWorkspace.shared.frontmostApplication?.localizedName
        switchTimestamps = []
        awayPingSentForCurrentPeriod = false
        lastNudgeAt = nil
    }

    private func tick() {
        let now = Date()

        idleSeconds = Self.systemIdleSeconds()

        let currentApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        if currentApp != lastAppName {
            switchTimestamps.append(now)
            appStreakStart = now
            lastAppName = currentApp
        }
        frontmostAppName = currentApp
        switchTimestamps.removeAll { now.timeIntervalSince($0) > FatigueConfig.switchWindowSeconds }
        switchCountInWindow = switchTimestamps.count
        appStreakSeconds = now.timeIntervalSince(appStreakStart)

        sessionSeconds = now.timeIntervalSince(sessionStart)
        isLateNight = Self.isLateNight(at: now)

        let newState = computeState(now: now)
        handleTransition(from: state, to: newState, now: now)
        state = newState
    }

    private func computeState(now: Date) -> CheckInState {
        if idleSeconds >= FatigueConfig.awayIdleThresholdSeconds {
            return .away
        }
        let longSessionLateNight = sessionSeconds >= FatigueConfig.longSessionThresholdSeconds && isLateNight
        if switchCountInWindow >= FatigueConfig.switchCountThreshold || longSessionLateNight {
            return .stalling
        }
        if appStreakSeconds >= FatigueConfig.flowMinSameAppSeconds && idleSeconds < FatigueConfig.flowMaxInputAgeSeconds {
            return .flow
        }
        return .active
    }

    private func handleTransition(from oldState: CheckInState, to newState: CheckInState, now: Date) {
        if oldState == .away && newState != .away {
            sessionStart = now
            appStreakStart = now
            switchTimestamps = []
            awayPingSentForCurrentPeriod = false
        }

        switch newState {
        case .away:
            if !awayPingSentForCurrentPeriod {
                awayPingSentForCurrentPeriod = true
                lastAwayPingAt = now
                let topic = appState.topic
                let message = appState.message
                Task {
                    try? await NtfyClient.send(topic: topic, message: message)
                }
            }
        case .stalling:
            fireNudgeIfCooledDown(now: now, state: newState, fallback: FatigueConfig.stallingNudgeMessage)
        case .active:
            fireNudgeIfCooledDown(now: now, state: newState, fallback: FatigueConfig.activeNudgeMessage)
        case .flow, .stopped:
            break
        }
    }

    private func fireNudgeIfCooledDown(now: Date, state: CheckInState, fallback: String) {
        let cooldown = max(appState.intervalMinutes, 0.5) * 60
        if let last = lastNudgeAt, now.timeIntervalSince(last) < cooldown {
            return
        }
        lastNudgeAt = now

        guard appState.useClaudeForNudges, KeychainStore.hasAPIKey() else {
            LocalNotifier.send(title: "Desk Teammate", body: fallback)
            return
        }

        let context = NudgeContext(
            state: state,
            idleSeconds: idleSeconds,
            appName: frontmostAppName,
            appStreakSeconds: appStreakSeconds,
            switchCount: switchCountInWindow,
            sessionSeconds: sessionSeconds,
            isLateNight: isLateNight
        )
        Task {
            let body = await ClaudeDelegate.generateNudgeMessage(context: context, fallback: fallback)
            LocalNotifier.send(title: "Desk Teammate", body: body)
        }
    }

    private static func systemIdleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    private static func isLateNight(at date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        if FatigueConfig.lateNightStartHour <= FatigueConfig.lateNightEndHour {
            return hour >= FatigueConfig.lateNightStartHour && hour < FatigueConfig.lateNightEndHour
        }
        return hour >= FatigueConfig.lateNightStartHour || hour < FatigueConfig.lateNightEndHour
    }
}
