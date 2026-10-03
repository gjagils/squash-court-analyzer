import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// The dashboard's local advice and AI Coach, on Darwin and Android
final class CoachAdviceTests: XCTestCase {
    /// Hugo wins 5 winners (drive, front left) in 3 s each; Jaïr wins 3
    /// points on Hugo's unforced errors in 20 s each
    private func game() -> Game {
        let game = Game()
        game.player1Name = "Hugo"
        game.player2Name = "Jaïr"
        var points: [Point] = []
        for index in 0..<5 {
            points.append(Point(scorer: Player.player1, pointType: PointType.winner, zone: CourtZone.frontLeft, shotType: ShotType.drive,
                                server: Player.player1, player1Score: index + 1, player2Score: 0, duration: 3))
        }
        for index in 0..<3 {
            points.append(Point(scorer: Player.player2, pointType: PointType.unforcedError, zone: nil, shotType: nil,
                                server: Player.player2, player1Score: 5, player2Score: index + 1, duration: 20))
        }
        game.points = points
        game.player1Score = 5
        game.player2Score = 3
        return game
    }

    func testFormatsDurations() {
        XCTAssertEqual(CoachAdvice.formatDuration(3), "3s")
        XCTAssertEqual(CoachAdvice.formatDuration(59.4), "59s")
        XCTAssertEqual(CoachAdvice.formatDuration(65), "1:05")
        XCTAssertEqual(CoachAdvice.formatDuration(130), "2:10")
    }

    func testLocalAdviceMostPotentialFirst() {
        let advice = CoachAdvice.local(in: game(), for: Player.player1)
        var texts: [String] = []
        for item in advice {
            texts.append(item.text)
        }
        // Hugo's 3 own errors are points to win back; what goes well counts for less
        XCTAssertEqual(texts, [
            "3 eigen fouten: blijf geconcentreerd en speel rustig.",
            "Je wint je punten vooral voorin (5 van 5). Blijf de voorhoeken zoeken.",
            "Je scoort vooral aan de linkerkant (5 van 5). Speel vaker die kant op.",
            "Voorin werkt je drive het best (5 punten).",
            "Versnel het spel: je gewonnen punten duren gemiddeld 3s, je verloren punten 20s.",
        ])
        XCTAssertEqual(advice[0].tone, AdviceTone.warning)
        XCTAssertEqual(advice[4].topic, AdviceTopic.speedUp)
    }

    func testTheOpponentSeesTheOtherSide() {
        let advice = CoachAdvice.local(in: game(), for: Player.player2)
        var texts: [String] = []
        for item in advice {
            texts.append(item.text)
        }
        XCTAssertEqual(texts, [
            "Je verliest de meeste punten voorin (5 van 5). Hugo maakt het kort af: sta dichter bij de T en reageer eerder op korte ballen.",
            "Je verliest de meeste punten aan de linkerkant (5 van 5). Daar is Hugo sterk.",
            "Vermijd Voor Links: daar scoort Hugo het meest (5 punten).",
            "Vertraag het spel: je gewonnen punten duren gemiddeld 20s, je verloren punten 3s.",
            "Hugo maakt 3 fouten: blijf druk zetten.",
        ])
    }

    func testNoTempoAdviceBelowFourPoints() {
        let short = game()
        short.points = Array(short.points.prefix(3))
        XCTAssertNil(CoachAdvice.tempo(in: short, for: Player.player1))
    }

    func testTopShots() {
        let shots = CoachAdvice.topShots(in: game(), for: Player.player1)
        XCTAssertEqual(shots, [ShotCount(shot: ShotType.drive, count: 5)])
    }

    func testGameSummaryText() {
        let text = GameSummaryText.text(for: game())
        XCTAssertTrue(text.contains("Hugo vs Jaïr"))
        // Not finished (5-3), so there is no winner yet; the text says so as iOS always did
        XCTAssertTrue(text.contains("Eindstand: 5-3 (Gelijkspel wint)"))
        XCTAssertTrue(text.contains("• Winners: 5 | Forced errors: 0 | Eigen fouten: 0"))
        XCTAssertTrue(text.contains("• Beste zone: Voor Links"))
        XCTAssertTrue(text.hasSuffix("📲 Gedeeld via Squash Analyzer"))
    }

    // MARK: AI Coach

    func testRequestNeverContainsPlayerNames() throws {
        let request = AICoachClient.prompt(game: game(), player: Player.player1, coachingFocus: ["Backhand"])
        let text = String(data: try AICoachClient.requestBody(request, model: "gpt-4.1-nano"), encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("gpt-4.1-nano"))
        XCTAssertTrue(text.contains("\"max_completion_tokens\":900"))
        XCTAssertTrue(text.contains("\"temperature\""))
        XCTAssertFalse(text.contains("reasoning_effort"))
        XCTAssertTrue(text.contains("Backhand"))
        XCTAssertFalse(text.contains("Hugo"))
        XCTAssertFalse(text.contains("Ja\\u00efr") || text.contains("Jaïr"))
        let prompt = AICoachPrompt.user(game: game(), player: Player.player1)
        XCTAssertTrue(prompt.contains("Eindstand: 5 - 3"))
        XCTAssertTrue(prompt.contains("Winners geslagen: 5"))
        XCTAssertTrue(prompt.contains("Voor Links: 5 gewonnen, 0 verloren"))
    }

    func testAReasoningModelGetsItsOwnSettings() throws {
        let request = AICoachClient.prompt(game: game(), player: Player.player1)
        let text = String(data: try AICoachClient.requestBody(request, model: "gpt-5-nano"), encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("\"reasoning_effort\":\"low\""))
        XCTAssertTrue(text.contains("\"max_completion_tokens\":3000"))
        XCTAssertFalse(text.contains("temperature"))
    }

    func testTheCheapestAvailableModelIsChosen() {
        XCTAssertEqual(AIModelChoice.pick(from: ["gpt-4o", "gpt-4o-mini", "gpt-4.1-nano", "whisper-1"]), "gpt-4.1-nano")
        XCTAssertEqual(AIModelChoice.pick(from: ["gpt-4o", "gpt-4o-mini"]), "gpt-4o-mini")
        // Models that do not exist yet: a nano before a mini, no audio/realtime variants
        XCTAssertEqual(AIModelChoice.pick(from: ["gpt-7-mini", "gpt-7-nano-realtime", "gpt-7-nano", "gpt-7"]), "gpt-7-nano")
        XCTAssertEqual(AIModelChoice.pick(from: ["gpt-7-mini-2027-01-01", "gpt-7-mini"]), "gpt-7-mini")
        XCTAssertEqual(AIModelChoice.pick(from: ["gpt-4.1-nano", "gpt-4o-mini"], except: ["gpt-4.1-nano"]), "gpt-4o-mini")
        XCTAssertNil(AIModelChoice.pick(from: ["gpt-4o", "dall-e-3"]))
    }

    private func chat(_ content: String) -> Data {
        let response = ChatResponse(choices: [ChatChoice(message: ChatChoiceMessage(content: content))])
        return (try? JSONEncoder().encode(response)) ?? Data()
    }

    private func thrown(_ body: () throws -> Void) -> Error? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    func testReadsTheAnswer() throws {
        let json = "{\"samenvatting\":\"Sterke game\",\"sterktePunten\":[\"Drive\"],\"werkPunten\":[\"Fouten\"],\"tactischAdvies\":[\"Druk\"],\"focusVolgendeGame\":\"Rustig\"}"
        let advice = try AICoachClient.advice(from: AITransportResponse(status: 200, body: chat(json)))
        XCTAssertEqual(advice.samenvatting, "Sterke game")
        XCTAssertEqual(advice.werkPunten, ["Fouten"])

        let plain = try AICoachClient.advice(from: AITransportResponse(status: 200, body: chat("Gewoon tekst")))
        XCTAssertEqual(plain.samenvatting, "Gewoon tekst")
        XCTAssertEqual(plain.focusVolgendeGame, "Analyseer je tegenstander en pas je tactiek aan")
    }

    func testErrorsAreNamed() {
        let unauthorized = thrown { _ = try AICoachClient.advice(from: AITransportResponse(status: 401, body: Data())) }
        XCTAssertEqual(unauthorized as? AICoachError, AICoachError.invalidAPIKey)
        let server = thrown { _ = try AICoachClient.advice(from: AITransportResponse(status: 500, body: Data())) }
        XCTAssertEqual(server as? AICoachError, AICoachError.apiError(statusCode: 500))
        let garbage = thrown { _ = try AICoachClient.advice(from: AITransportResponse(status: 200, body: "nee".data(using: .utf8)!)) }
        XCTAssertEqual(garbage as? AICoachError, AICoachError.invalidResponse)
    }

    private func models(_ ids: [String]) -> AITransportResponse {
        let list = ids.map { "{\"id\":\"\($0)\"}" }.joined(separator: ",")
        return AITransportResponse(status: 200, body: "{\"data\":[\(list)]}".data(using: .utf8)!)
    }

    func testClientAsksTheChosenModelWithTheKey() async throws {
        let transport = FakeAITransport(models: models(["gpt-4o", "gpt-4o-mini"]),
                                        answers: [AITransportResponse(status: 200, body: chat("Prima"))])
        let advice = try await AICoachClient(transport: transport).advice(for: game(), player: Player.player1, apiKey: "sk-test")
        XCTAssertEqual(advice.samenvatting, "Prima")
        XCTAssertEqual(transport.headers["Authorization"], "Bearer sk-test")
        XCTAssertEqual(transport.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(transport.askedModels, ["gpt-4o-mini"])
    }

    func testARetiredModelIsSkippedOnce() async throws {
        let retired = AITransportResponse(status: 404, body: "{\"error\":{\"code\":\"model_not_found\"}}".data(using: .utf8)!)
        let transport = FakeAITransport(models: models(["gpt-4.1-nano", "gpt-4o-mini"]),
                                        answers: [retired, AITransportResponse(status: 200, body: chat("Prima"))])
        let advice = try await AICoachClient(transport: transport).advice(for: game(), player: Player.player1, apiKey: "sk-test")
        XCTAssertEqual(advice.samenvatting, "Prima")
        XCTAssertEqual(transport.askedModels, ["gpt-4.1-nano", "gpt-4o-mini"])
    }

    func testWithoutAModelListThePreferredModelIsTriedAndAWrongKeyIsNamed() async throws {
        let transport = FakeAITransport(models: nil, answers: [AITransportResponse(status: 200, body: chat("Prima"))])
        _ = try await AICoachClient(transport: transport).advice(for: game(), player: Player.player1, apiKey: "sk-test")
        XCTAssertEqual(transport.askedModels, [AIModelChoice.preferred[0]])

        let wrongKey = FakeAITransport(models: AITransportResponse(status: 401, body: Data()), answers: [])
        do {
            _ = try await AICoachClient(transport: wrongKey).advice(for: game(), player: Player.player1, apiKey: "sk-fout")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? AICoachError, AICoachError.invalidAPIKey)
        }
    }

    func testNoConnectionIsNamed() async throws {
        do {
            _ = try await AICoachClient(transport: FakeAITransport(models: nil, answers: [])).advice(for: game(), player: Player.player1, apiKey: "sk-test")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(error as? AICoachError, AICoachError.noConnection)
        }
    }
}

/// Answers the model list with `models` and each question with the next of
/// `answers`; nil or no answer left fails like a lost connection
final class FakeAITransport: AICoachTransport, @unchecked Sendable {
    let models: AITransportResponse?
    var answers: [AITransportResponse]
    var headers: [String: String] = [:]
    var url: URL?
    var askedModels: [String] = []

    init(models: AITransportResponse?, answers: [AITransportResponse]) {
        self.models = models
        self.answers = answers
    }

    func get(_ url: URL, headers: [String: String]) async throws -> AITransportResponse {
        guard let models else { throw URLError(.notConnectedToInternet) }
        return models
    }

    func post(_ url: URL, headers: [String: String], body: Data) async throws -> AITransportResponse {
        self.url = url
        self.headers = headers
        if let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any], let model = json["model"] as? String {
            askedModels.append(model)
        }
        guard !answers.isEmpty else { throw URLError(.notConnectedToInternet) }
        return answers.removeFirst()
    }
}
