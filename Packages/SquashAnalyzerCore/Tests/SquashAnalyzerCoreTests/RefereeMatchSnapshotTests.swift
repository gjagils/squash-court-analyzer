import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// iOS keeps an unfinished referee match as this snapshot, so "Sluiten" can be resumed
final class RefereeMatchSnapshotTests: XCTestCase {
    func testAMatchInTheSecondGameComesBackAsItWas() throws {
        let match = RefereeMatch(player1Name: "Gerard", player2Name: "Thé", bestOf: 5, startingServer: Player.player2)
        match.player1Id = UUID()
        for _ in 0..<11 { match.awardPoint(to: Player.player1) }
        match.confirmNextGame()
        match.awardPoint(to: Player.player2)
        match.callStroke(to: Player.player1)
        match.overrideSide(to: ServerSide.left)

        let data = try JSONEncoder().encode(match.snapshot)
        let restored = try XCTUnwrap(RefereeMatch.restoring(try JSONDecoder().decode(RefereeMatchSnapshot.self, from: data)))
        XCTAssertEqual(restored.id, match.id)
        XCTAssertEqual(restored.player1Id, match.player1Id)
        XCTAssertEqual(restored.currentGameNumber, 2)
        XCTAssertEqual(restored.player1Score, match.player1Score)
        XCTAssertEqual(restored.player2Score, match.player2Score)
        XCTAssertEqual(restored.currentServer, match.currentServer)
        XCTAssertEqual(restored.serverSide, match.serverSide)
        XCTAssertEqual(restored.completedGames.count, 1)
        XCTAssertEqual(restored.completedGames[0].points.count, 11)
        XCTAssertEqual(restored.pointHistory.count, match.pointHistory.count)
        XCTAssertEqual(restored.matchStartedAt, match.matchStartedAt)
        XCTAssertEqual(restored.snapshot, match.snapshot)
    }
}
