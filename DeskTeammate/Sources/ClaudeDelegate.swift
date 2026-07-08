import Foundation

/// Everything the delegate needs to write a relevant one-liner, without
/// reaching back into CheckInEngine internals.
struct NudgeContext {
    let state: CheckInState
    let idleSeconds: TimeInterval
    let appName: String
    let appStreakSeconds: TimeInterval
    let switchCount: Int
    let sessionSeconds: TimeInterval
    let isLateNight: Bool
}

enum ClaudeDelegateError: Error {
    case noAPIKey
    case badResponse
}

/// Uses the user's own Claude API key (Keychain-only, see KeychainStore) to
/// turn a nudge into a short, witty, in-character line instead of a canned
/// string. Never blocks the UI and never throws outward — any failure
/// (missing key, network error, bad response) just falls back to the static
/// message that was going to be sent anyway.
enum ClaudeDelegate {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-haiku-4-5-20251001"
    private static let requestTimeout: TimeInterval = 8

    static func generateNudgeMessage(context: NudgeContext, fallback: String) async -> String {
        guard let apiKey = KeychainStore.getAPIKey(), !apiKey.isEmpty else {
            return fallback
        }
        do {
            let text = try await requestMessage(context: context, apiKey: apiKey)
            return text.isEmpty ? fallback : text
        } catch {
            return fallback
        }
    }

    private static func requestMessage(context: NudgeContext, apiKey: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestBody(
            model: model,
            max_tokens: 40,
            system: systemPrompt,
            messages: [.init(role: "user", content: userPrompt(for: context))]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ClaudeDelegateError.badResponse
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let text = decoded.content.first?.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"")) else {
            throw ClaudeDelegateError.badResponse
        }
        return text
    }

    /// Shared with ClaudeChatSession so the nudge voice and chat voice never
    /// drift apart. The nudge-specific "keep it to one short line" formatting
    /// instruction is tacked on here rather than baked into the shared prompt,
    /// since that constraint is unique to nudges (chat replies can run longer).
    private static var systemPrompt: String {
        Personality.systemPrompt + """


        For this reply specifically: ONE short line only (max ~15 words). \
        No quotes, no emoji, no hashtags, no preamble.
        """
    }

    private static func userPrompt(for c: NudgeContext) -> String {
        switch c.state {
        case .stalling:
            let lateNightSuffix = c.isLateNight ? ", and it's late at night" : ""
            return "The user has switched apps \(c.switchCount) times in the last few minutes and seems scattered\(lateNightSuffix). Nudge them to refocus on one thing."
        case .active:
            let minutes = Int(c.sessionSeconds / 60)
            return "The user has been working for about \(minutes) minutes on \(c.appName). Give a quick, encouraging check-in."
        default:
            return "Give a short, in-character check-in line for someone working at their desk."
        }
    }

    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
        struct Message: Encodable { let role: String; let content: String }
    }

    private struct ResponseBody: Decodable {
        let content: [ContentBlock]
        struct ContentBlock: Decodable { let text: String }
    }
}
