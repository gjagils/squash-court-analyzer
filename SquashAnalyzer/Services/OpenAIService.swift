import Foundation
import SquashAnalyzerCore

// AI Coach's prompt, request and answer parsing live in SquashAnalyzerCore
// (`AICoachClient`, shared with Android); iOS sends the request with URLSession.

extension AICoachError: @retroactive LocalizedError {
    public var errorDescription: String? { message }
}

struct URLSessionAICoachTransport: AICoachTransport {
    func post(_ url: URL, headers: [String: String], body: Data) async throws -> AITransportResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        return AITransportResponse(status: (response as? HTTPURLResponse)?.statusCode ?? 0, body: data)
    }
}

/// Service for generating tactical advice using OpenAI's GPT API
enum OpenAIService {
    static let client = AICoachClient(transport: URLSessionAICoachTransport())
}
