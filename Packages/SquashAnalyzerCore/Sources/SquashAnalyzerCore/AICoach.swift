import Foundation

// AI Coach: tactical advice from OpenAI for one game, shared by iOS and
// Android. The prompt, the request and reading the answer live here; sending
// the request is per platform (`AICoachTransport`), like Mijn team's page
// loader, and so is keeping the API key (`APIKeyStore`: Keychain on iOS, an
// Android-Keystore-encrypted value on Android). Player names never leave the
// device: the prompt says "Speler" and "Tegenstander".

public struct TacticalAdvice: Codable, Equatable, Sendable {
    public let samenvatting: String
    public let sterktePunten: [String]
    public let werkPunten: [String]
    public let tactischAdvies: [String]
    public let focusVolgendeGame: String

    public init(samenvatting: String, sterktePunten: [String], werkPunten: [String], tactischAdvies: [String], focusVolgendeGame: String) {
        self.samenvatting = samenvatting
        self.sterktePunten = sterktePunten
        self.werkPunten = werkPunten
        self.tactischAdvies = tactischAdvies
        self.focusVolgendeGame = focusVolgendeGame
    }
}

public enum AICoachError: Error, Equatable {
    case invalidResponse
    case invalidAPIKey
    case apiError(statusCode: Int)
    case noContent
    case noConnection

    public var message: String {
        switch self {
        case .invalidResponse: return "Ongeldig antwoord van server"
        case .invalidAPIKey: return "Ongeldige API key. Controleer je instellingen."
        case .apiError(let code): return "API fout (code: \(code))"
        case .noContent: return "Geen antwoord ontvangen"
        case .noConnection: return "Geen verbinding met de AI Coach. Controleer je internetverbinding."
        }
    }
}

/// Where the OpenAI API key is kept
public protocol APIKeyStore: AnyObject {
    var openAIAPIKey: String? { get set }
}

extension APIKeyStore {
    public var hasOpenAIKey: Bool {
        guard let key = openAIAPIKey else { return false }
        return !key.isEmpty
    }
}

public struct AITransportResponse: Sendable {
    public let status: Int
    public let body: Data

    public init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }
}

/// Sends one HTTPS POST: URLSession on iOS, HttpURLConnection on Android
public protocol AICoachTransport: Sendable {
    func post(_ url: URL, headers: [String: String], body: Data) async throws -> AITransportResponse
}

public enum AICoachPrompt {
    public static let model = "gpt-4o-mini"
    public static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    public static let system = """
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

    /// The game in numbers, without any names
    public static func user(game: Game, player: Player, coachingFocus: [String] = []) -> String {
        let opponent = player.opponent
        let playerName = "Speler"
        let opponentName = "Tegenstander"

        var zoneStats: [String] = []
        for zone in CourtZone.allCases {
            let won = game.pointsWon(by: player, in: zone)
            let lost = game.pointsWon(by: opponent, in: zone)
            if won > 0 || lost > 0 {
                zoneStats.append("\(zone.rawValue): \(won) gewonnen, \(lost) verloren")
            }
        }
        var shotStats: [String] = []
        for shot in CoachAdvice.topShots(in: game, for: player, limit: 20) {
            shotStats.append("\(shot.name): \(shot.count) punten")
        }
        let volleys = game.volleysWon(by: player).count
        let court = game.heatmapLayout == CourtLayout.nine
            ? "9 vakken (voor/midden/achter × links/midden/rechts)"
            : "6 vakken (voor/midden/achter × links/rechts)"
        let bestZone = game.bestZone(for: player)?.rawValue ?? "geen"
        let bestShot = game.bestShotType(for: player)?.rawValue ?? "geen"
        let worstZone = game.bestZone(for: opponent)?.rawValue ?? "geen"
        let coachingSection = coachingFocus.isEmpty ? "" : "\nCOACHING AANDACHTSPUNTEN:\n- Focus: \(coachingFocus.joined(separator: ", "))"

        return """
        SQUASH GAME ANALYSE

        Speler: \(playerName)
        Tegenstander: \(opponentName)
        Eindstand: \(game.player1Score) - \(game.player2Score)
        Winnaar: \(game.winner == player ? playerName : opponentName)

        STATISTIEKEN VOOR \(playerName.uppercased()):
        - Totaal punten gewonnen: \(game.pointsWon(by: player).count)
        - Totaal punten verloren: \(game.pointsWon(by: opponent).count)
        - Winners geslagen: \(game.winners(by: player).count)
        - Forced errors afgedwongen: \(game.forcedErrors(by: player).count)
        - Eigen unforced errors: \(game.unforcedErrors(by: opponent).count)
        - Cadeautjes (unforced errors tegenstander): \(game.unforcedErrors(by: player).count)
        - Strokes toegekend: \(game.strokes(by: player).count)
        - Servicepunten (direct uit de service): \(game.servicePoints(by: player).count)
        - Punten uit de lucht (volleys): \(volleys)
        - Beste zone: \(bestZone)
        - Beste slag: \(bestShot)
        - Zone waar tegenstander scoorde: \(worstZone)

        De baan is verdeeld in \(court). Links/rechts is de forehand- of backhandkant, afhankelijk van de speler.

        PUNTEN PER ZONE (winners + forced errors):
        \(zoneStats.isEmpty ? "geen data" : zoneStats.joined(separator: "\n"))

        SLAGEN:
        \(shotStats.isEmpty ? "geen data" : shotStats.joined(separator: "\n"))
        \(coachingSection)
        Geef tactisch advies voor \(playerName) voor de volgende game tegen \(opponentName).
        """
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct ChatChoiceMessage: Codable {
    let content: String
}

struct ChatChoice: Codable {
    let message: ChatChoiceMessage
}

struct ChatResponse: Codable {
    let choices: [ChatChoice]
}

public struct AICoachClient: Sendable {
    let transport: any AICoachTransport

    public init(transport: any AICoachTransport) {
        self.transport = transport
    }

    /// The request body OpenAI gets. Built before sending, on the caller's
    /// side, so the (non-Sendable) `Game` never crosses into the async call.
    public static func requestBody(game: Game, player: Player, coachingFocus: [String] = []) throws -> Data {
        let request = ChatRequest(model: AICoachPrompt.model,
                                  messages: [ChatMessage(role: "system", content: AICoachPrompt.system),
                                             ChatMessage(role: "user", content: AICoachPrompt.user(game: game, player: player, coachingFocus: coachingFocus))],
                                  temperature: 0.7, maxTokens: 500)
        return try JSONEncoder().encode(request)
    }

    /// Reads OpenAI's answer. An answer that is not the asked-for JSON becomes
    /// a summary-only advice, as before.
    static func advice(from response: AITransportResponse) throws -> TacticalAdvice {
        if response.status == 401 { throw AICoachError.invalidAPIKey }
        guard response.status == 200 else { throw AICoachError.apiError(statusCode: response.status) }
        guard let chat = try? JSONDecoder().decode(ChatResponse.self, from: response.body) else { throw AICoachError.invalidResponse }
        guard let content = chat.choices.first?.message.content else { throw AICoachError.noContent }
        if let json = content.data(using: String.Encoding.utf8), let advice = try? JSONDecoder().decode(TacticalAdvice.self, from: json) {
            return advice
        }
        return TacticalAdvice(samenvatting: content, sterktePunten: [], werkPunten: [], tactischAdvies: [],
                              focusVolgendeGame: "Analyseer je tegenstander en pas je tactiek aan")
    }

    public func advice(for game: Game, player: Player, apiKey: String, coachingFocus: [String] = []) async throws -> TacticalAdvice {
        try await send(try AICoachClient.requestBody(game: game, player: player, coachingFocus: coachingFocus), apiKey: apiKey)
    }

    /// Sends a body from `requestBody(game:player:coachingFocus:)`
    public func send(_ body: Data, apiKey: String) async throws -> TacticalAdvice {
        let headers = ["Authorization": "Bearer \(apiKey)", "Content-Type": "application/json"]
        let response: AITransportResponse
        do {
            response = try await transport.post(AICoachPrompt.endpoint, headers: headers, body: body)
        } catch {
            throw AICoachError.noConnection
        }
        return try AICoachClient.advice(from: response)
    }
}
