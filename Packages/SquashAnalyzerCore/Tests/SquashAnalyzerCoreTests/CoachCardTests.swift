import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// De coachkaart: three points per game, related to the game before
final class CoachCardTests: XCTestCase {

    /// These tests check the Dutch texts, whatever language the test machine has
    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }
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

/// Whose coach card opens first, and service/return over the match
final class CoachCardFocusTests: XCTestCase {

    /// These tests check the Dutch texts, whatever language the test machine has
    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }
    func testTheCardOpensOnThePlayerFromTheTeam() {
        let jan = UUID()
        let piet = UUID()
        XCTAssertEqual(CoachCard.focus(player1Id: jan, player2Id: piet, team: [piet.uuidString]), Player.player2)
        XCTAssertEqual(CoachCard.focus(player1Id: jan, player2Id: piet, team: [jan.uuidString.lowercased()]), Player.player1)
        XCTAssertEqual(CoachCard.focus(player1Id: jan, player2Id: piet, team: [jan.uuidString, piet.uuidString]), Player.player1, "both: the first named")
        XCTAssertEqual(CoachCard.focus(player1Id: jan, player2Id: piet, team: []), Player.player1, "neither: the first named")
        XCTAssertEqual(CoachCard.focus(player1Id: nil, player2Id: piet, team: [piet.uuidString]), Player.player2)
    }

    func testServiceAndReturnOverTheMatchAndTheTrend() {
        let match = Match()
        match.setupMatch(player1: "Jan", player2: "Piet", startingServer: .player1)
        // Game 1: Jan serves and wins everything
        while !match.currentGame.isGameOver {
            match.currentGame.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        }
        match.onGameEnd()
        // Game 2: Jan loses his serve straight away, then Piet wins everything
        while !match.currentGame.isGameOver {
            match.currentGame.addPoint(to: Player.player2, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        }
        let first = ServiceReturnStats.of(match.games[0], for: Player.player1)
        let second = ServiceReturnStats.of(match.games[1], for: Player.player1)
        XCTAssertEqual(first.servePercentage, 100)
        XCTAssertEqual(second.servePercentage, 0, "the one rally he served, he lost")
        XCTAssertEqual(ServiceReturnStats.trend(second.servePercentage, first.servePercentage), "▼ 100")
        XCTAssertEqual(ServiceReturnStats.trend(50, 40), "▲ 10")
        XCTAssertEqual(ServiceReturnStats.trend(50, 50), "=")
        XCTAssertNil(ServiceReturnStats.trend(nil, 50))
        let total = ServiceReturnStats.of(match, through: 1, for: Player.player1)
        XCTAssertEqual(total.served, first.served + second.served)
        XCTAssertEqual(ServiceReturnStats.of(match, through: 0, for: Player.player1), first)
    }
}
