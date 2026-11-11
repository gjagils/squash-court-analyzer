import Foundation

// "Stel een vraag" in the app (Gerd-Jan, 11 November 2026): the same answer as
// the box at the top of the manual, from the website Worker's /api/vraag
// (Workers AI, from the manual only). The question is not stored there.

public struct ManualAnswerLink: Codable, Equatable, Sendable {
    public let title: String
    public let href: String

    /// The manual page and section on the website
    public var url: URL? { URL(string: ManualQuestion.site + href) }
}

public struct ManualAnswer: Codable, Equatable, Sendable {
    public let answer: String
    public let links: [ManualAnswerLink]
}

public enum ManualQuestionError: Error, Equatable {
    /// More than ten questions a minute from this address
    case busy
    case failed
}

struct ManualQuestionRequest: Codable {
    let question: String
    let lang: String
    let platform: String
}

public enum ManualQuestion {
    static let site = "https://www.squashanalyzer.com"

    /// A question the Worker accepts: 3 to 300 characters after trimming
    public static func isAskable(_ text: String) -> Bool {
        let count = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).count
        return count >= 3 && count <= 300
    }

    public static func ask(_ question: String, english: Bool, android: Bool,
                           transport: any LiveTransport) async throws -> ManualAnswer {
        let text = question.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard isAskable(text), let url = URL(string: site + "/api/vraag") else { throw ManualQuestionError.failed }
        let body = try JSONEncoder().encode(ManualQuestionRequest(question: text, lang: english ? "en" : "nl",
                                                                  platform: android ? "android" : "iphone"))
        let response: AITransportResponse
        do {
            response = try await transport.send(method: "POST", url: url,
                                                headers: ["Content-Type": "application/json", "Accept": "application/json"], body: body)
        } catch {
            throw ManualQuestionError.failed
        }
        if response.status == 429 { throw ManualQuestionError.busy }
        guard response.status == 200, let value = try? JSONDecoder().decode(ManualAnswer.self, from: response.body),
              !value.answer.isEmpty else { throw ManualQuestionError.failed }
        return value
    }
}
