import Foundation

enum NtfyError: Error {
    case invalidTopic
    case server(Int)
}

enum NtfyClient {
    static func send(topic: String, message: String) async throws {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTopic.isEmpty,
              let url = URL(string: "https://ntfy.sh/\(trimmedTopic)") else {
            throw NtfyError.invalidTopic
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(message.utf8)

        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NtfyError.server(http.statusCode)
        }
    }
}
