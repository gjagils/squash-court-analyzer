import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// De coachkaart: three points per game, related to the game before
final class CoachCardTests: XCTestCase {
    /// One game: player 1's own errors at the front, player 2's errors at the
    /// front (a chance for player 1), then winners until the game is over
    private func play(_ match: Match, ownErrors: Int, opponentErrors: Int, winner: Player = Player.player2) {
        let game = match.currentGame
        for _ in 0..<ownErrors {
            game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: CourtZone.frontLeft, with: nil)
        }
        for _ in 0..<opponentErrors {
            game.addPoint(to: Player.player1, pointType: PointType.unforcedError, at: CourtZone.frontRight, with: nil)
        }
        while !game.isGameOver {
            game.addPoint(to: winner, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        }
        match.onGameEnd()
    }

    private func newMatch() -> Match {
        let match = Match()
        match.setupMatch(player1: "Jan", player2: "Piet", startingServer: .player1)
        return match
    }

    func testTheFirstGameGivesThreePointsWithoutComparison() {
        let match = newMatch()
        play(match, ownErrors: 6, opponentErrors: 0)
        let card = CoachCard.make(match: match, gameIndex: 0, player: Player.player1)
        XCTAssertEqual(card.gameNumber, 1)
        XCTAssertNil(card.previousGameNumber)
        XCTAssertFalse(card.points.isEmpty)
        XCTAssertTrue(card.points.count <= CoachCard.pointCount)
        XCTAssertTrue(card.changes.isEmpty)
        for point in card.points { XCTAssertEqual(point.mark, CoachCardMark.new) }
    }

    func testAWorkPointThatStaysIsStillThereAndOneThatGoesIsImproved() {
        let match = newMatch()
        play(match, ownErrors: 6, opponentErrors: 0)
        play(match, ownErrors: 6, opponentErrors: 0)
        play(match, ownErrors: 0, opponentErrors: 0, winner: Player.player1)

        let second = CoachCard.make(match: match, gameIndex: 1, player: Player.player1)
        XCTAssertEqual(second.previousGameNumber, 1)
        XCTAssertTrue(second.points.contains { point in point.mark == CoachCardMark.stillThere }, "the errors came back")
        XCTAssertEqual(CoachCardMark.stillThere.label, "Nog steeds")

        let third = CoachCard.make(match: match, gameIndex: 2, player: Player.player1)
        XCTAssertTrue(third.changes.contains { point in point.mark == CoachCardMark.improved }, "no own errors this time")
        XCTAssertEqual(CoachCardMark.improved.label, "Verbeterd!")
    }

    func testSomethingThatWorkedBeforeIsPointedOutWhenItIsGone() {
        let match = newMatch()
        play(match, ownErrors: 0, opponentErrors: 6, winner: Player.player1)
        play(match, ownErrors: 0, opponentErrors: 0)
        let card = CoachCard.make(match: match, gameIndex: 1, player: Player.player1)
        let pickUp = card.changes.first { point in point.mark.label == "Pak dit op zoals je in game 1 deed" }
        XCTAssertNotNil(pickUp, "Piet's errors at the front were a chance in game 1")
        XCTAssertEqual(pickUp?.mark.label, "Pak dit op zoals je in game 1 deed")
        XCTAssertTrue(card.changes.count <= CoachCard.changeCount)
    }

    func testGamesAfterAHeadStartKeepTheirMatchNumbers() {
        let match = Match()
        match.setupMatch(player1: "Jan", player2: "Piet", startingServer: .player1, player1GamesBefore: 1, player2GamesBefore: 0)
        play(match, ownErrors: 6, opponentErrors: 0)
        play(match, ownErrors: 6, opponentErrors: 0)
        let card = CoachCard.make(match: match, gameIndex: 1, player: Player.player1)
        XCTAssertEqual(card.gameNumber, 3)
        XCTAssertEqual(card.previousGameNumber, 2)
    }
}
