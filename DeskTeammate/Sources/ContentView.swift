import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: CheckInEngine
    @State private var showDebug = false
    @State private var apiKeyInput: String = ""
    @State private var hasAPIKey: Bool = KeychainStore.hasAPIKey()
    @State private var apiKeyStatus: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Desk Teammate")
                    .font(.headline)
                Spacer()
                StateBadge(state: engine.state)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("ntfy topic")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. harman-desk-teammate-92x", text: $state.topic)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Phone message (when away)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Message", text: $state.message)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Nudge cooldown")
                Stepper(value: $state.intervalMinutes, in: 1...120, step: 1) {
                    Text("\(Int(state.intervalMinutes)) min")
                        .monospacedDigit()
                }
            }

            Toggle("Check-in engine running", isOn: $state.isRunning)
                .toggleStyle(.switch)

            Toggle("Dock character", isOn: $state.showDockCharacter)
                .toggleStyle(.switch)

            if state.showDockCharacter {
                Picker("", selection: $state.dockCharacterKind) {
                    ForEach(DockCharacterKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Button("Send test ping now") {
                Task { await state.sendPing() }
            }
            .disabled(state.topic.trimmingCharacters(in: .whitespaces).isEmpty)

            if !state.lastPingResult.isEmpty {
                Text(state.lastPingResult)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Claude API key")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if hasAPIKey {
                    HStack {
                        Text("Stored in Keychain ✓")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Replace") {
                            hasAPIKey = false
                            apiKeyStatus = ""
                        }
                        .font(.caption)
                    }
                } else {
                    SecureField("Paste key", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Save to Keychain") {
                            let saved = KeychainStore.setAPIKey(apiKeyInput)
                            apiKeyInput = ""
                            hasAPIKey = KeychainStore.hasAPIKey()
                            apiKeyStatus = saved ? "Saved." : "Failed to save."
                        }
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        if !apiKeyStatus.isEmpty {
                            Text(apiKeyStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Toggle("Smart nudges (Claude writes them)", isOn: $state.useClaudeForNudges)
                    .toggleStyle(.switch)
                    .disabled(!hasAPIKey)
                    .font(.caption)
                if !hasAPIKey {
                    Text("Add a key above to enable Claude-written nudges.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            DisclosureGroup("Debug signals", isExpanded: $showDebug) {
                DebugPanel(engine: engine)
                    .padding(.top, 4)
            }
            .font(.caption)

            Divider()

            Button("Quit Desk Teammate") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

private struct StateBadge: View {
    let state: CheckInState

    var color: Color {
        switch state {
        case .stopped: return .gray
        case .flow: return .green
        case .active: return .blue
        case .stalling: return .orange
        case .away: return .red
        }
    }

    var body: some View {
        Text(state.rawValue)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

private struct DebugPanel: View {
    @ObservedObject var engine: CheckInEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            row("Idle", format(engine.idleSeconds))
            row("Frontmost app", engine.frontmostAppName)
            row("App streak", format(engine.appStreakSeconds))
            row("Switches in window", "\(engine.switchCountInWindow)")
            row("Session length", format(engine.sessionSeconds))
            row("Late night", engine.isLateNight ? "yes" : "no")
            row("Last nudge", relative(engine.lastNudgeAt))
            row("Last away ping", relative(engine.lastAwayPingAt))
        }
        .font(.caption.monospaced())
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func relative(_ date: Date?) -> String {
        guard let date else { return "-" }
        let seconds = Int(Date().timeIntervalSince(date))
        return "\(seconds)s ago"
    }
}
