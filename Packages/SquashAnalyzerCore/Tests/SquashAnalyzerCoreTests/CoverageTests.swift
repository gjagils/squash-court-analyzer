import XCTest
import Foundation
@testable import SquashAnalyzerCore

// Paths the code analysis found untested (T25): the three share texts and
// the hour notation, what Stop does, and which OpenAI model is tried.
final class ShareTextTests: XCTestCase {

    private func report(duration: TimeInterval, winner: Player? = Player.player1) -> MatchShareReport {
        let games = [
            MatchShareReport.Game(number: 1, player1Score: 11, player2Score: 7, winner: Player.player1,
                                  duration: 600.0, rallyWinners: Array(repeating: Player.player1, count: 5), strokes: 1),
            MatchShareReport.Game(number: 2, player1Score: 4, player2Score: 2, winner: nil,
                                  duration: nil, rallyWinners: [], strokes: 0),
        ]
        return MatchShareReport(player1Name: "Jan", player2Name: "Piet", bestOf: 5, firstGameNumber: 1,
                                player1Games: 1, player2Games: 0, matchWinner: winner, games: games,
                                startedAt: Date(timeIntervalSince1970: 1_790_000_000), duration: duration)
    }

    func testScorecardIsAMonospaceTable() {
        let text = report(duration: 1200.0).text(style: MatchShareStyle.scorecard)
        let lines = text.components(separatedBy: "\n")
        XCTAssertEqual(lines.first, "🏸 *SQUASH SCOREKAART*")
        XCTAssertEqual(lines.filter { $0 == "```" }.count, 2)
        XCTAssertTrue(lines.contains { $0.hasPrefix("Jan") && $0.hasSuffix("  11   4") })
        XCTAssertTrue(text.contains("20 min"))
    }

    func testReportHasEveryGameAndTheStats() {
        let text = report(duration: 1200.0).text(style: MatchShareStyle.report)
        XCTAssertTrue(text.contains("*Game 1* · 11-7 · ✅ Jan · 10 min · 1 stroke"))
        XCTAssertTrue(text.contains("*Game 2* · 4-2 · bezig"))
        XCTAssertTrue(text.contains("🔥 langste reeks 5 (Jan)"))
        XCTAssertTrue(text.hasSuffix("_Gescoord met Squash Analyzer_"))
    }

    func testAnHourOrMoreIsWrittenInHours() {
        XCTAssertTrue(report(duration: 3900.0).text(style: MatchShareStyle.scorecard).contains("1 u 05 min"))
        XCTAssertTrue(report(duration: 20.0).text(style: MatchShareStyle.scorecard).contains("1 min"), "never 0 min")
    }

    func testTheStandMidMatch() {
        let text = report(duration: 600.0, winner: nil).text(style: MatchShareStyle.compact)
        XCTAssertTrue(text.contains("*Jan* 1 – 0 Piet"))
        XCTAssertTrue(text.contains("11-7 · 4-2…"))
    }
}

final class CoachStopTests: XCTestCase {

    private func match() -> Match {
        let match = Match()
        match.setupMatch(player1: "Jan", player2: "Piet", startingServer: Player.player1)
        return match
    }

    func testAnEmptyMatchIsDroppedWithoutAsking() {
        XCTAssertEqual(match().stopAction, CoachStopAction.discard)
    }

    func testAMatchWithARallyAsks() {
        let match = match()
        match.currentGame.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.frontLeft, with: ShotType.drive)
        XCTAssertEqual(match.stopAction, CoachStopAction.ask)
    }

    func testALetAloneAlsoAsks() {
        let match = match()
        match.currentGame.addLet(requestedBy: Player.player2)
        XCTAssertEqual(match.stopAction, CoachStopAction.ask)
    }

    func testALateStartAsksEvenWithoutRallies() {
        let match = Match()
        match.setupMatch(player1: "Jan", player2: "Piet", startingServer: Player.player1,
                         player1GamesBefore: 1, player2GamesBefore: 1)
        XCTAssertEqual(match.stopAction, CoachStopAction.ask, "the games before are worth keeping")
    }
}

final class AIModelChoiceTests: XCTestCase {

    func testWithoutAModelListThePreferredOnesAreTriedInOrder() {
        XCTAssertEqual(AIModelChoice.fallback(except: []), AIModelChoice.preferred.first)
        XCTAssertEqual(AIModelChoice.fallback(except: [AIModelChoice.preferred[0]]), AIModelChoice.preferred[1])
        XCTAssertNil(AIModelChoice.fallback(except: AIModelChoice.preferred))
    }

    func testAnUnknownNanoBeatsAMiniAndSpecialModelsAreSkipped() {
        XCTAssertEqual(AIModelChoice.pick(from: ["gpt-9-mini", "gpt-9-nano-realtime", "gpt-9-nano"]), "gpt-9-nano")
        XCTAssertEqual(AIModelChoice.pick(from: ["gpt-9-mini-2027-01-01", "gpt-9-mini"]), "gpt-9-mini", "base name before a dated snapshot")
        XCTAssertNil(AIModelChoice.pick(from: ["whisper-1", "gpt-9-audio-mini"]))
    }

    func testReasoningModels() {
        XCTAssertTrue(AIModelChoice.isReasoning("gpt-5-nano"))
        XCTAssertTrue(AIModelChoice.isReasoning("o4-mini"))
        XCTAssertFalse(AIModelChoice.isReasoning("gpt-4.1-nano"))
    }
}
