import XCTest
import Foundation
@testable import SquashAnalyzerCore

// The referee's calls flash as a banner (LET, STROKE -> NAME); they ran only
// in the iOS tests before, so never through Skip.
final class RefereeCallTests: XCTestCase {

    /// These tests check the Dutch texts, whatever language the test machine has
    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }

    func testStrokeRemembersWhoGotIt() {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        match.callStroke(to: Player.player2)
        XCTAssertEqual(match.player2Score, 1)
        XCTAssertEqual(match.lastDecision, RefereeDecision.stroke(Player.player2))
        XCTAssertEqual(match.pointHistory.last?.isStroke, true)
    }

    func testLetIsADecisionWithoutAPoint() {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        match.callLet()
        XCTAssertEqual(match.lastDecision, RefereeDecision.letCall)
        XCTAssertEqual(match.player1Score + match.player2Score, 0)
    }

    func testTheNextRallyClearsTheDecision() {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        match.callStroke(to: Player.player1)
        match.awardPoint(to: Player.player2)
        XCTAssertNil(match.lastDecision)
    }

    func testAStrokeGivesThePointToThePlayerItIsAwardedTo() {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        match.callStroke(to: Player.player2)
        XCTAssertEqual(match.player1Score, 0)
        XCTAssertEqual(match.player2Score, 1)
        XCTAssertEqual(match.currentServer, Player.player2)
    }

    func testTheDecisionStaysUntilTheNextRallyOrUndo() {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        match.callLet()
        XCTAssertEqual(match.lastDecision, RefereeDecision.letCall)
        match.callStroke(to: Player.player1)
        XCTAssertEqual(match.lastDecision, RefereeDecision.stroke(Player.player1))
        match.undo()
        XCTAssertNil(match.lastDecision)
    }
}
