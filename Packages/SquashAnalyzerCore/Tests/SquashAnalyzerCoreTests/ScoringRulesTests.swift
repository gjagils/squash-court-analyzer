import XCTest
import Foundation
@testable import SquashAnalyzerCore

// The squash rules (score, service, head start) in the Core package, so they
// also run on Android through Skip. Before, they lived only in the iOS tests.
// Enum types are written out in full where Skip needs them (docs/android-port.md).
final class ScoringRulesTests: XCTestCase {

    func testGameEndsAtElevenWithTwoPointLead() {
        let engine = ScoringEngine()
        XCTAssertTrue(engine.isGameOver(SquashScore(player1: 11, player2: 9)))
        XCTAssertFalse(engine.isGameOver(SquashScore(player1: 11, player2: 10)))
        XCTAssertTrue(engine.isGameOver(SquashScore(player1: 15, player2: 13)))
        XCTAssertEqual(engine.winner(for: SquashScore(player1: 9, player2: 11)), Player.player2)
    }

    func testServiceRule() {
        let engine = ScoringEngine()
        let start = ServiceState(server: Player.player1, side: ServerSide.right)
        // The server who wins keeps serving from the other box
        XCTAssertEqual(engine.service(afterRallyWonBy: Player.player1, from: start, handOutSide: ServerSide.right),
                       ServiceState(server: Player.player1, side: ServerSide.left))
        // Hand-out: the new server starts from their hand-out box
        XCTAssertEqual(engine.service(afterRallyWonBy: Player.player2, from: start, handOutSide: ServerSide.left),
                       ServiceState(server: Player.player2, side: ServerSide.left))
        let replayed = engine.service(replaying: [Player.player1, Player.player1, Player.player2, Player.player2], from: start,
                                      handOutSide: { _ in ServerSide.right })
        XCTAssertEqual(replayed, ServiceState(server: Player.player2, side: ServerSide.left))
    }

    func testServiceBoxAlternatesAndHandOutUsesPreferredBox() {
        let game = Game()
        game.assignStartingServer(Player.player1)
        XCTAssertEqual(game.serverSide, ServerSide.right)
        game.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.frontLeft, with: ShotType.drop)
        XCTAssertEqual(game.currentServer, Player.player1)
        XCTAssertEqual(game.serverSide, ServerSide.left)
        game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.currentServer, Player.player2)
        XCTAssertEqual(game.serverSide, ServerSide.right)
        game.overrideSide(to: ServerSide.left)
        XCTAssertEqual(game.preferredSide(for: Player.player2), ServerSide.left)
        game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.serverSide, ServerSide.right)
        game.addPoint(to: Player.player1, pointType: PointType.unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.serverSide, ServerSide.right)
        game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.currentServer, Player.player2)
        XCTAssertEqual(game.serverSide, ServerSide.left, "player 2's hand-out box")
    }

    func testUndoRestoresServiceBox() {
        let game = Game()
        game.assignStartingServer(Player.player1)
        game.addPoint(to: Player.player1, pointType: PointType.unforcedError, at: nil, with: nil)
        game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil)
        game.undoLastPoint()
        XCTAssertEqual(game.currentServer, Player.player1)
        XCTAssertEqual(game.serverSide, ServerSide.left)
        game.undoLastPoint()
        XCTAssertEqual(game.serverSide, ServerSide.right)
    }

    /// T9: a restored game used to put a server who won rallies back in the hand-out box
    func testRestoredGameKeepsTheBoxAlternation() {
        let game = Game()
        game.assignStartingServer(Player.player1)
        game.addPoint(to: Player.player1, pointType: PointType.unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.serverSide, ServerSide.left)
        game.restoreServiceState()
        XCTAssertEqual(game.currentServer, Player.player1)
        XCTAssertEqual(game.serverSide, ServerSide.left, "server won one rally: other box")

        game.addPoint(to: Player.player1, pointType: PointType.unforcedError, at: nil, with: nil)
        game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil)
        game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil)
        let live = ServiceState(server: game.currentServer, side: game.serverSide)
        game.restoreServiceState()
        XCTAssertEqual(ServiceState(server: game.currentServer, side: game.serverSide), live)
    }

    func testRefereeServiceRuleIsTheSame() {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        match.awardPoint(to: Player.player1)
        XCTAssertEqual(match.serverSide, ServerSide.left)
        match.awardPoint(to: Player.player2)
        XCTAssertEqual(match.currentServer, Player.player2)
        XCTAssertEqual(match.serverSide, ServerSide.right)
    }

    func testMatchStand() {
        XCTAssertEqual(MatchStand.gamesToWin(bestOf: 5), 3)
        XCTAssertEqual(MatchStand.gamesToWin(bestOf: 3), 2)
        XCTAssertNil(MatchStand(bestOf: 5, player1Games: 2, player2Games: 2).winner)
        XCTAssertEqual(MatchStand(bestOf: 5, player1Games: 1, player2Games: 3).winner, Player.player2)
        XCTAssertTrue(MatchStand(bestOf: 3, player1Games: 2, player2Games: 0).isOver)
    }

    func testHeadStartCountsTowardsTheStandAndGameNumbers() {
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: Player.player2, player1GamesBefore: 1, player2GamesBefore: 1)
        XCTAssertEqual(match.firstGameNumber, 3)
        XCTAssertEqual(match.currentGameNumber, 3)
        XCTAssertEqual(match.currentGame.currentServer, Player.player2)
        XCTAssertFalse(match.isMatchOver)
        for _ in 0..<11 { match.currentGame.addPoint(to: Player.player1, pointType: PointType.unforcedError, at: nil, with: nil) }
        XCTAssertEqual(match.player1GamesWon, 2)
        match.onGameEnd()
        XCTAssertEqual(match.currentGameNumber, 4)
        for _ in 0..<11 { match.currentGame.addPoint(to: Player.player1, pointType: PointType.unforcedError, at: nil, with: nil) }
        XCTAssertTrue(match.isMatchOver)
        XCTAssertEqual(match.matchWinner, Player.player1)
        XCTAssertEqual(match.games.count, 2, "only the tracked games exist")
    }

    func testHeadStartThatAlreadyDecidesTheMatchIsIgnored() {
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: Player.player1, player1GamesBefore: 3, player2GamesBefore: 0)
        XCTAssertEqual(match.player1GamesBefore, 0)
        XCTAssertFalse(Match.isValidHeadStart(player1: 2, player2: 3))
        XCTAssertTrue(Match.isValidHeadStart(player1: 2, player2: 2))
    }

    func testRefereeHeadStartAndUnconfirmedFinalGame() {
        let match = RefereeMatch(player1Name: "A", player2Name: "B", bestOf: 5, startingServer: Player.player1,
                                 player1GamesBefore: 2, player2GamesBefore: 0)
        XCTAssertEqual(match.firstGameNumber, 3)
        for _ in 0..<11 { match.awardPoint(to: Player.player1) }
        XCTAssertTrue(match.isMatchOver, "the final game counts before Volgende game")
        XCTAssertEqual(match.matchWinner, Player.player1)
    }
}
