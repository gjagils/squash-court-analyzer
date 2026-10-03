import XCTest
import Foundation
@testable import SquashAnalyzerCore

// The result card's texts, its badges and the WhatsApp preview of "Deel
// score" (moved from the UI package so they run on both platforms, T19)
final class ResultAndShareTextTests: XCTestCase {

    // MARK: - WhatsApp preview

    func testBoldAndItalicPiecesAreSplit() {
        let segments = ChatMarkup.segments("*Jan* wint _3-1_")
        XCTAssertEqual(segments.map { $0.text }, ["Jan", " wint ", "3-1"])
        XCTAssertEqual(segments.map { $0.bold }, [true, false, false])
        XCTAssertEqual(segments.map { $0.italic }, [false, false, true])
    }

    func testAnUnpairedStarStaysAsText() {
        let segments = ChatMarkup.segments("5*3 rallies")
        XCTAssertEqual(segments.map { $0.text }.joined(), "5*3 rallies")
        XCTAssertFalse(segments.contains { $0.bold })
    }

    func testMonospaceBlocksAndEmptyLines() {
        let blocks = ChatMarkup.blocks("Uitslag\n\n```\nG1 11-7\nG2 9-11\n```\nKlaar")
        XCTAssertEqual(blocks.count, 4)
        XCTAssertEqual(blocks[1].segments.first?.text, " ", "an empty line keeps its height")
        XCTAssertEqual(blocks[2].mono, "G1 11-7\nG2 9-11")
        XCTAssertNil(blocks[3].mono)
    }

    // MARK: - Result card

    private func refereeGameWon(strokes: Int) -> RefereeMatch {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        for _ in 0..<strokes { match.callStroke(to: Player.player1) }
        for _ in strokes..<11 { match.awardPoint(to: Player.player1) }
        return match
    }

    func testStandTextCountsTheGameJustWon() {
        let match = refereeGameWon(strokes: 0)
        XCTAssertTrue(match.isGameOver)
        XCTAssertEqual(MatchResult.standText(match), "Jan leidt 1 – 0")
    }

    func testGameStatsCountRalliesAndStrokes() {
        XCTAssertTrue(MatchResult.gameStatsText(refereeGameWon(strokes: 1)).hasSuffix(" · 11 rallies · 1 stroke"))
        XCTAssertTrue(MatchResult.gameStatsText(refereeGameWon(strokes: 2)).hasSuffix(" · 11 rallies · 2 strokes"))
        XCTAssertTrue(MatchResult.gameStatsText(refereeGameWon(strokes: 0)).hasSuffix(" · 11 rallies"))
    }

    func testMatchStatsShowAtLeastOneMinute() {
        XCTAssertTrue(MatchResult.matchStatsText(refereeGameWon(strokes: 0)).hasPrefix("1 min · "))
    }

    // MARK: - Badges on the result card

    func testOnlyPickedPlayersWithABadgeAreListed() {
        let rallies = Array(repeating: BadgeRally(winner: Player.player1, shot: nil, pointType: nil), count: 5)
        let input = BadgeMatchInput(games: [BadgeGame(rallies: rallies, winner: nil)], player1GamesBefore: 0, player2GamesBefore: 0)
        let picked = UUID()

        let earnings = MatchBadgeEarning.earnings(player1Id: picked, player1Name: "Jan", player2Id: UUID(), player2Name: "Piet",
                                                  badgeInput: input)
        XCTAssertEqual(earnings.count, 1, "Piet earned nothing")
        XCTAssertEqual(earnings.first?.playerId, picked)
        XCTAssertEqual(earnings.first?.name, "Jan")
        XCTAssertTrue(earnings.first?.badges.contains(BadgeKind.fiveInARow) == true)

        let typedIn = MatchBadgeEarning.earnings(player1Id: nil, player1Name: "Jan", player2Id: nil, player2Name: "Piet",
                                                 badgeInput: input)
        XCTAssertTrue(typedIn.isEmpty, "typed-in names have no card to put a badge on")
    }
}
