import XCTest
import Foundation
@testable import SquashAnalyzerCore

// Best of 1, 3 or 5 (Gerd-Jan, 22 October 2026): a training match is often
// shorter than best of 5. The format is chosen in the setup; the stand, the
// head start, the live snapshot and the share text follow it.
// Enum types are written out in full where Skip needs them (docs/android-port.md).
final class BestOfTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }

    private func winGame(_ match: Match, for player: Player) {
        for _ in 0..<11 {
            match.currentGame.addPoint(to: player, pointType: PointType.winner, at: nil, with: nil)
        }
        match.onGameEnd()
    }

    func testFormatsAndTheFallback() {
        XCTAssertEqual(Match.bestOfOptions, [1, 3, 5])
        XCTAssertEqual(Match.validBestOf(3), 3)
        XCTAssertEqual(Match.validBestOf(1), 1)
        XCTAssertEqual(Match.validBestOf(7), 5, "a format the setup does not offer is best of 5")
        XCTAssertEqual(Match.validBestOf(0), 5)
        XCTAssertEqual(Match().bestOf, 5, "5 by default")
    }

    func testCoachBestOfThreeIsOverAfterTwoGames() {
        let match = Match()
        match.setupMatch(player1: "Bas", player2: "Tim", startingServer: Player.player1, bestOf: 3)
        XCTAssertEqual(match.bestOf, 3)
        XCTAssertEqual(match.gamesToWin, 2)

        winGame(match, for: Player.player1)
        XCTAssertFalse(match.isMatchOver)
        XCTAssertEqual(match.games.count, 2, "game 2 started")
        winGame(match, for: Player.player1)
        XCTAssertTrue(match.isMatchOver)
        XCTAssertEqual(match.matchWinner, Player.player1)
        XCTAssertEqual(match.games.count, 2, "no game 3 in best of 3")
        XCTAssertEqual(match.stopAction, CoachStopAction.finish, "Stop saves it as finished, no questions")
        XCTAssertEqual(match.liveSnapshot().bestOf, 3)
        XCTAssertTrue(match.whatsAppText.contains("best of 3"))
    }

    func testCoachBestOfOneIsOverAfterOneGame() {
        let match = Match()
        match.setupMatch(player1: "Bas", player2: "Tim", startingServer: Player.player2, bestOf: 1)
        winGame(match, for: Player.player2)
        XCTAssertTrue(match.isMatchOver)
        XCTAssertEqual(match.matchWinner, Player.player2)
        XCTAssertEqual(match.games.count, 1)
    }

    func testHeadStartFitsTheFormat() {
        XCTAssertTrue(Match.isValidHeadStart(player1: 1, player2: 1, bestOf: 3))
        XCTAssertFalse(Match.isValidHeadStart(player1: 2, player2: 0, bestOf: 3), "2 games is the match in best of 3")
        XCTAssertFalse(Match.isValidHeadStart(player1: 1, player2: 0, bestOf: 1))
        XCTAssertTrue(Match.isValidHeadStart(player1: 2, player2: 2, bestOf: 5))

        let match = Match()
        match.setupMatch(player1: "Bas", player2: "Tim", startingServer: Player.player1,
                         player1GamesBefore: 2, player2GamesBefore: 0, bestOf: 3)
        XCTAssertEqual(match.player1GamesBefore, 0, "a head start that already decides the match is dropped")
        match.setupMatch(player1: "Bas", player2: "Tim", startingServer: Player.player1,
                         player1GamesBefore: 1, player2GamesBefore: 0, bestOf: 3)
        XCTAssertEqual(match.player1GamesBefore, 1)
        XCTAssertEqual(match.firstGameNumber, 2)
        winGame(match, for: Player.player1)
        XCTAssertTrue(match.isMatchOver, "1 before plus 1 tracked is the match")
    }

    func testCompletingTheResultFollowsTheFormat() {
        let match = Match()
        match.setupMatch(player1: "Bas", player2: "Tim", startingServer: Player.player1, bestOf: 3)
        winGame(match, for: Player.player1)
        XCTAssertTrue(match.completeResult(with: [Player.player2, Player.player2]))
        XCTAssertEqual(match.matchWinner, Player.player2)
        XCTAssertEqual(match.player2GamesWon, 2)
    }

    func testRefereeBestOfThree() {
        let match = RefereeMatch(player1Name: "Bas", player2Name: "Tim", bestOf: 3, startingServer: Player.player1)
        XCTAssertEqual(match.gamesToWin, 2)
        for _ in 0..<11 { match.awardPoint(to: Player.player2) }
        match.confirmNextGame()
        XCTAssertFalse(match.isMatchOver)
        for _ in 0..<11 { match.awardPoint(to: Player.player2) }
        XCTAssertEqual(match.allGameResults.count, 2)
        match.confirmNextGame()
        XCTAssertTrue(match.isMatchOver)
        XCTAssertEqual(match.matchWinner, Player.player2)
        XCTAssertEqual(match.liveSnapshot.bestOf, 3)
    }
}
