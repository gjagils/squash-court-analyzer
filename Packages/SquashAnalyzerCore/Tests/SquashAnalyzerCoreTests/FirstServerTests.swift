import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// Who serves first can still change just before the match starts
final class FirstServerTests: XCTestCase {
    func testTheRefereeChangesTheFirstServerUntilTheFirstRally() {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        XCTAssertTrue(match.canChangeFirstServer)
        match.overrideSide(to: ServerSide.left)
        match.changeFirstServer(to: Player.player2)
        XCTAssertEqual(match.currentServer, Player.player2)
        XCTAssertEqual(match.serverSide, ServerSide.right, "the new server starts from the right box")
        match.awardPoint(to: Player.player2)
        XCTAssertFalse(match.canChangeFirstServer)
        match.changeFirstServer(to: Player.player1)
        XCTAssertEqual(match.currentServer, Player.player2, "not after a rally")
        XCTAssertEqual(match.player2Score, 1)
        match.undo()
        XCTAssertEqual(match.currentServer, Player.player2, "undo goes back to the changed server")
        XCTAssertTrue(match.canChangeFirstServer)
    }

    func testTheCoachChangesTheFirstServerUntilGameOneStarts() {
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: Player.player1)
        XCTAssertTrue(match.canChangeFirstServer)
        match.changeFirstServer(to: Player.player2)
        XCTAssertEqual(match.matchStartingServer, Player.player2)
        XCTAssertEqual(match.currentGame.currentServer, Player.player2)
        XCTAssertEqual(match.currentGame.startingServer, Player.player2)
        match.currentGame.start()
        XCTAssertFalse(match.canChangeFirstServer)
        match.changeFirstServer(to: Player.player1)
        XCTAssertEqual(match.currentGame.currentServer, Player.player2, "not once the game is started")
    }
}
