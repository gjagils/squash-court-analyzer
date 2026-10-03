import XCTest
import Foundation
@testable import SquashAnalyzerCore

// Reading a match never changes it, and durations follow an injected clock
final class MatchStateTests: XCTestCase {

    /// T11: completing a match that only had an untouched game keeps that game,
    /// and reading `currentGame` afterwards adds nothing
    func testCompletedMatchKeepsOneGameAndReadingAddsNone() {
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: Player.player1)
        XCTAssertEqual(match.games.count, 1)
        XCTAssertTrue(match.completeResult(with: [Player.player1, Player.player1, Player.player1]))
        XCTAssertEqual(match.status, MatchStatus.completed)
        XCTAssertEqual(match.games.count, 1, "the only game is kept")
        _ = match.currentGame
        _ = match.liveSnapshot()
        XCTAssertEqual(match.games.count, 1, "reading adds no game")
        XCTAssertEqual(match.player1GamesWon, 3)
    }

    func testEmptiedGamesGiveADetachedGame() {
        let match = Match()
        match.games = []
        let game = match.currentGame
        XCTAssertEqual(game.player1Score, 0)
        XCTAssertTrue(match.games.isEmpty, "not added")
    }

    func testRallyDurationFollowsTheClock() {
        let game = Game()
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        game.now = { Date(timeIntervalSince1970: 1_790_000_012.5) }
        game.start(at: start)
        game.addPoint(to: Player.player1, pointType: PointType.unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.points.last?.duration, 12.5)
        XCTAssertEqual(game.points.last?.timestamp, Date(timeIntervalSince1970: 1_790_000_012.5))
    }

    func testNoLetAfterTheGameIsOver() {
        let game = Game()
        for _ in 0..<11 { game.addPoint(to: Player.player1, pointType: PointType.unforcedError, at: nil, with: nil) }
        game.addLet(requestedBy: Player.player2)
        XCTAssertEqual(game.lets.count, 0)
    }

    func testRefereeClock() {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        let moment = Date(timeIntervalSince1970: 1_790_000_100)
        match.now = { moment }
        match.awardPoint(to: Player.player1)
        XCTAssertEqual(match.lastPointAt, moment)
    }
}
