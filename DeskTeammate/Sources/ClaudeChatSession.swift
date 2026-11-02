import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Role: String { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

/// Backs the live chat popup: keeps a rolling conversation with the same
/// Anthropic Messages API + Keychain key ClaudeDelegate already uses, but
/// multi-turn instead of one-shot. Same never-throw-outward fallback
/// philosophy — a missing key or network error just becomes an in-voice
/// canned reply instead of a stuck spinner or a crash.
@MainActor
final class ClaudeChatSession: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isThinking = false

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-haiku-4-5-20251001"
    private static let requestTimeout: TimeInterval = 20
    private static let maxHistoryMessages = 12

    private static let noKeyFallback = "Add your Claude API key in settings first. I can't banter on vibes alone."
    private static let errorFallback = "Signal's down for a second there. Try that again."

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(role: .user, text: trimmed))
        isThinking = true
        defer { isThinking = false }

        guard let apiKey = KeychainStore.getAPIKey(), !apiKey.isEmpty else {
            messages.append(ChatMessage(role: .assistant, text: Self.noKeyFallback))
            return
        }
        do {
            let reply = try await requestReply(apiKey: apiKey)
            messages.append(ChatMessage(role: .assistant, text: reply))
        } catch {
            messages.append(ChatMessage(role: .assistant, text: Self.errorFallback))
        }
    }

    private func requestReply(apiKey: String) async throws -> String {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.requestTimeout
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var history = Array(messages.suffix(Self.maxHistoryMessages))
        if history.first?.role == .assistant {
            history.removeFirst()
        }
        let apiMessages = history.map { RequestBody.Message(role: $0.role.rawValue, content: $0.text) }

        let body = RequestBody(
            model: Self.model,
            max_tokens: 300,
            system: Personality.systemPrompt,
            messages: apiMessages
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ClaudeDelegateError.badResponse
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let text = decoded.content.first?.text
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw ClaudeDelegateError.badResponse
        }
        return text
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
