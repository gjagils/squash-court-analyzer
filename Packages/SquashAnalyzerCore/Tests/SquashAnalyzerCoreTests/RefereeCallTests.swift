import XCTest
import Foundation
@testable import SquashAnalyzerCore

// The referee's calls flash as a banner (LET, STROKE -> NAME); they ran only
// in the iOS tests before, so never through Skip.
final class RefereeCallTests: XCTestCase {

    func testStrokeShowsTheBannerWithTheName() {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        match.callStroke(to: Player.player2)
        XCTAssertEqual(match.player2Score, 1)
        XCTAssertEqual(match.lastCallText, "STROKE -> PIET")
        XCTAssertEqual(match.pointHistory.last?.isStroke, true)
    }

    func testLetShowsTheBannerWithoutAPoint() {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        match.callLet()
        XCTAssertEqual(match.lastCallText, "LET")
        XCTAssertEqual(match.player1Score + match.player2Score, 0)
    }

    func testTheNextRallyClearsTheBanner() {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        match.callStroke(to: Player.player1)
        match.awardPoint(to: Player.player2)
        XCTAssertNil(match.lastCallText)
    }
}
