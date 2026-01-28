import Foundation

/// Service for generating tactical advice using OpenAI's GPT API
actor OpenAIService {
    static let shared = OpenAIService()

    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o-mini"  // Cost-effective and fast

    private init() {}

    /// Generate tactical advice based on game data
    func generateTacticalAdvice(
        for game: Game,
        player: Player,
        apiKey: String
    ) async throws -> TacticalAdvice {
        let prompt = buildPrompt(for: game, player: player)

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": """
                    Je bent een ervaren squash coach. Analyseer de gegeven game statistieken en geef concreet, actionable advies in het Nederlands.

                    Antwoord ALLEEN in dit exacte JSON formaat (geen markdown, geen extra tekst):
                    {
                        "samenvatting": "Korte samenvatting van de game in 1-2 zinnen",
                        "sterktePunten": ["punt 1", "punt 2", "punt 3"],
                        "werkPunten": ["punt 1", "punt 2"],
                        "tactischAdvies": ["advies 1", "advies 2", "advies 3"],
                        "focusVolgendeGame": "Één concrete focus voor de volgende game"
                    }
                    """
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.7,
            "max_tokens": 500
        ]

        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw OpenAIError.invalidAPIKey
            }
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode)
        }

        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard let content = openAIResponse.choices.first?.message.content else {
            throw OpenAIError.noContent
        }

        // Parse the JSON response from GPT
        guard let jsonData = content.data(using: .utf8),
              let advice = try? JSONDecoder().decode(TacticalAdvice.self, from: jsonData) else {
            // If JSON parsing fails, create a basic response
            return TacticalAdvice(
                samenvatting: content,
                sterktePunten: [],
                werkPunten: [],
                tactischAdvies: [],
                focusVolgendeGame: "Analyseer je tegenstander en pas je tactiek aan"
            )
        }

        return advice
    }

    private func buildPrompt(for game: Game, player: Player) -> String {
        let opponent = player.opponent
        let playerName = game.name(for: player)
        let opponentName = game.name(for: opponent)

        // Gather statistics
        let playerPoints = game.pointsWon(by: player)
        let opponentPoints = game.pointsWon(by: opponent)

        // Zone breakdown
        var zoneStats: [String] = []
        for zone in CourtZone.allCases {
            let won = game.pointsWon(by: player, in: zone)
            let lost = game.pointsWon(by: opponent, in: zone)
            if won > 0 || lost > 0 {
                zoneStats.append("\(zone.rawValue): \(won) gewonnen, \(lost) verloren")
            }
        }

        // Shot type breakdown
        var shotStats: [String] = []
        for shotType in ShotType.allCases {
            let count = game.pointsWon(by: player, with: shotType)
            if count > 0 {
                shotStats.append("\(shotType.rawValue): \(count) punten")
            }
        }

        // Best zones and shots
        let bestZone = game.bestZone(for: player)?.rawValue ?? "geen"
        let bestShot = game.bestShotType(for: player)?.rawValue ?? "geen"
        let worstZone = game.bestZone(for: opponent)?.rawValue ?? "geen"

        return """
        SQUASH GAME ANALYSE

        Speler: \(playerName)
        Tegenstander: \(opponentName)
        Eindstand: \(game.player1Score) - \(game.player2Score)
        Winnaar: \(game.winner == player ? playerName : opponentName)

        STATISTIEKEN VOOR \(playerName.uppercased()):
        - Totaal punten gewonnen: \(playerPoints.count)
        - Totaal punten verloren: \(opponentPoints.count)
        - Beste zone: \(bestZone)
        - Beste slag: \(bestShot)
        - Zone waar tegenstander scoorde: \(worstZone)

        PUNTEN PER ZONE:
        \(zoneStats.joined(separator: "\n"))

        SLAGEN:
        \(shotStats.joined(separator: "\n"))

        Geef tactisch advies voor \(playerName) voor de volgende game tegen \(opponentName).
        """
    }
}

// MARK: - Models

struct TacticalAdvice: Codable {
    let samenvatting: String
    let sterktePunten: [String]
    let werkPunten: [String]
    let tactischAdvies: [String]
    let focusVolgendeGame: String
}

struct OpenAIResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

enum OpenAIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidAPIKey
    case apiError(statusCode: Int)
    case noContent

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ongeldige URL"
        case .invalidResponse:
            return "Ongeldig antwoord van server"
        case .invalidAPIKey:
            return "Ongeldige API key. Controleer je instellingen."
        case .apiError(let code):
            return "API fout (code: \(code))"
        case .noContent:
            return "Geen antwoord ontvangen"
        }
    }
}
