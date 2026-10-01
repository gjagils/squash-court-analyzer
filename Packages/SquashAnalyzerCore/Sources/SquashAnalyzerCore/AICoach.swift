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

/// Sends one HTTPS request: URLSession on iOS, HttpURLConnection on Android
public protocol AICoachTransport: Sendable {
    func post(_ url: URL, headers: [String: String], body: Data) async throws -> AITransportResponse
    /// For the list of models the key may use
    func get(_ url: URL, headers: [String: String]) async throws -> AITransportResponse
}

public enum AICoachPrompt {
    public static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    public static let modelsEndpoint = URL(string: "https://api.openai.com/v1/models")!

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
        let profile = ZoneProfile.of(game, for: player)
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

        WAAR DE PUNTEN VALLEN (per rij en kant):
        - Gewonnen (eigen winners + forced errors): \(ZoneProfile.describe(profile.won))
        - Verloren (winners + forced errors tegenstander): \(ZoneProfile.describe(profile.lost))
        - Eigen fouten: \(ZoneProfile.describe(profile.errors))

        PUNTEN PER ZONE (alle punten met een zone):
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
    /// Not for reasoning models, which only take the default
    let temperature: Double?
    let maxCompletionTokens: Int
    /// Only for reasoning models (gpt-5, o-series)
    let reasoningEffort: String?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxCompletionTokens = "max_completion_tokens"
        case reasoningEffort = "reasoning_effort"
    }
}

struct ModelList: Codable {
    let data: [ModelEntry]
}

struct ModelEntry: Codable {
    let id: String
}

/// The system and user text for one question, made before sending so the
/// (non-Sendable) `Game` never crosses into the async call
public struct AICoachRequest: Equatable, Sendable {
    public let system: String
    public let user: String
}

/// Which OpenAI model to use: the cheapest suitable chat model the key may
/// use, so a model that is retired is simply not chosen anymore. OpenAI's API
/// gives no prices, so "cheapest" is this preference order (cheapest first),
/// and otherwise a "nano" before a "mini" chat model.
public enum AIModelChoice {
    public static let preferred = ["gpt-4.1-nano", "gpt-4o-mini", "gpt-5-nano", "gpt-4.1-mini", "gpt-5-mini"]

    /// Not plain chat models
    static let excluded = ["audio", "realtime", "search", "transcribe", "tts", "image", "embedding", "instruct", "codex", "vision", "preview"]

    public static func pick(from available: [String], except tried: [String] = []) -> String? {
        for model in preferred where available.contains(model) && !tried.contains(model) {
            return model
        }
        var nano: [String] = []
        var mini: [String] = []
        for id in available where id.hasPrefix("gpt-") && !tried.contains(id) {
            var special = false
            for word in excluded where id.contains(word) {
                special = true
            }
            if special { continue }
            if id.contains("nano") { nano.append(id) } else if id.contains("mini") { mini.append(id) }
        }
        // Newest family first, a dated snapshot ("…-2025-04-14") after its base name
        nano.sort { first, second in first.count == second.count ? first > second : first.count < second.count }
        mini.sort { first, second in first.count == second.count ? first > second : first.count < second.count }
        return nano.first ?? mini.first
    }

    /// The model to try when the list could not be fetched: the first preferred one not tried yet
    public static func fallback(except tried: [String]) -> String? {
        for model in preferred where !tried.contains(model) {
            return model
        }
        return nil
    }

    /// gpt-5 and the o-series reason first: no temperature, room for the reasoning
    public static func isReasoning(_ model: String) -> Bool {
        model.hasPrefix("gpt-5") || model.hasPrefix("o1") || model.hasPrefix("o3") || model.hasPrefix("o4")
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

    /// The texts for one game; build this before any `await`
    public static func prompt(game: Game, player: Player, coachingFocus: [String] = []) -> AICoachRequest {
        AICoachRequest(system: AICoachPrompt.system, user: AICoachPrompt.user(game: game, player: player, coachingFocus: coachingFocus))
    }

    /// The request body OpenAI gets for `model`
    public static func requestBody(_ request: AICoachRequest, model: String) throws -> Data {
        let reasoning = AIModelChoice.isReasoning(model)
        let chat = ChatRequest(model: model,
                               messages: [ChatMessage(role: "system", content: request.system),
                                          ChatMessage(role: "user", content: request.user)],
                               temperature: reasoning ? nil : 0.7,
                               maxCompletionTokens: reasoning ? 3000 : 500,
                               reasoningEffort: reasoning ? "low" : nil)
        return try JSONEncoder().encode(chat)
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
        try await send(AICoachClient.prompt(game: game, player: player, coachingFocus: coachingFocus), apiKey: apiKey)
    }

    /// Picks the cheapest model the key may use and asks it. When OpenAI does
    /// not know that model (retired), the next one is tried once.
    public func send(_ request: AICoachRequest, apiKey: String) async throws -> TacticalAdvice {
        let headers = ["Authorization": "Bearer \(apiKey)", "Content-Type": "application/json"]
        let available = try await models(headers: headers)
        var tried: [String] = []
        var attempt = 0
        while attempt < 2 {
            attempt += 1
            guard let model = AIModelChoice.pick(from: available, except: tried) ?? AIModelChoice.fallback(except: tried) else { break }
            tried.append(model)
            let response: AITransportResponse
            do {
                response = try await transport.post(AICoachPrompt.endpoint, headers: headers,
                                                    body: try AICoachClient.requestBody(request, model: model))
            } catch let error as AICoachError {
                throw error
            } catch {
                throw AICoachError.noConnection
            }
            if attempt < 2 && AICoachClient.modelUnavailable(response) { continue }
            return try AICoachClient.advice(from: response)
        }
        throw AICoachError.apiError(statusCode: 404)
    }

    /// The models this key may use; empty when the list could not be read
    /// (then the preferred list is tried). A wrong key stops here.
    func models(headers: [String: String]) async throws -> [String] {
        guard let response = try? await transport.get(AICoachPrompt.modelsEndpoint, headers: headers) else { return [] }
        if response.status == 401 { throw AICoachError.invalidAPIKey }
        guard response.status == 200, let list = try? JSONDecoder().decode(ModelList.self, from: response.body) else { return [] }
        var ids: [String] = []
        for entry in list.data {
            ids.append(entry.id)
        }
        return ids
    }

    /// OpenAI answers 404 (model_not_found) for a model that does not exist (anymore)
    static func modelUnavailable(_ response: AITransportResponse) -> Bool {
        if response.status == 404 { return true }
        guard response.status == 400, let text = String(data: response.body, encoding: String.Encoding.utf8) else { return false }
        return text.contains("model_not_found") || text.contains("does not exist")
    }
}
