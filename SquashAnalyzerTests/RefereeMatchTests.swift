import XCTest
@testable import SquashAnalyzer

final class RefereeMatchTests: XCTestCase {
    private func makeMatch(startingServer: Player = .player1) -> RefereeMatch {
        RefereeMatch(player1Name: "A", player2Name: "B", bestOf: 5, startingServer: startingServer)
    }

    func testServerWhoWinsRallyAlternatesServiceBox() {
        let match = makeMatch()
        XCTAssertEqual(match.serverSide, .right)

        match.awardPoint(to: .player1)
        XCTAssertEqual(match.currentServer, .player1)
        XCTAssertEqual(match.serverSide, .left)

        match.awardPoint(to: .player1)
        XCTAssertEqual(match.serverSide, .right)
    }

    func testHandOutGivesNewServerTheRightBox() {
        let match = makeMatch()
        match.awardPoint(to: .player1)          // A serves from left now
        match.awardPoint(to: .player2)          // hand-out
        XCTAssertEqual(match.currentServer, .player2)
        XCTAssertEqual(match.serverSide, .right)
    }

    func testSideOverrideIsRespectedAndAlternationContinuesFromIt() {
        let match = makeMatch()
        match.awardPoint(to: .player2)          // hand-out, B on right
        match.overrideSide(to: .left)           // B actually chose left
        XCTAssertEqual(match.serverSide, .left)
        XCTAssertEqual(match.pointHistory.last?.label, "1L")

        match.awardPoint(to: .player2)
        XCTAssertEqual(match.serverSide, .right)
        XCTAssertEqual(match.pointHistory.last?.label, "2R")
    }

    func testPointHistoryRecordsScoreAndBoxPerRally() {
        let match = makeMatch()
        match.awardPoint(to: .player1)
        match.awardPoint(to: .player1)
        match.awardPoint(to: .player2)
        match.callStroke(to: .player2)

        XCTAssertEqual(match.pointHistory.map(\.label), ["1L", "2R", "1R", "2L"])
        XCTAssertEqual(match.pointHistory.map(\.scorer), [.player1, .player1, .player2, .player2])
        XCTAssertEqual(match.pointHistory.map(\.isStroke), [false, false, false, true])
    }

    func testUndoRestoresServerSideAndHistory() {
        let match = makeMatch()
        match.awardPoint(to: .player1)
        match.awardPoint(to: .player2)
        match.overrideSide(to: .left)

        match.undo()                            // undo override
        XCTAssertEqual(match.serverSide, .right)
        XCTAssertEqual(match.pointHistory.last?.label, "1R")

        match.undo()                            // undo B's point
        XCTAssertEqual(match.currentServer, .player1)
        XCTAssertEqual(match.serverSide, .left)
        XCTAssertEqual(match.player2Score, 0)
        XCTAssertEqual(match.pointHistory.count, 1)

        match.undo()
        XCTAssertEqual(match.pointHistory.count, 0)
        XCTAssertFalse(match.canUndo)
    }

    func testWinnerOfGameServesFirstInNextGame() {
        let match = makeMatch(startingServer: .player1)
        for _ in 0..<11 { match.awardPoint(to: .player2) }
        XCTAssertTrue(match.isGameOver)
        XCTAssertEqual(match.currentGameWinner, .player2)

        match.confirmNextGame()
        XCTAssertEqual(match.currentGameNumber, 2)
        XCTAssertEqual(match.currentServer, .player2)
        XCTAssertEqual(match.serverSide, .right)
        XCTAssertTrue(match.pointHistory.isEmpty)
        XCTAssertFalse(match.canUndo)
    }

    func testNoPointsAfterGameIsOver() {
        let match = makeMatch()
        for _ in 0..<11 { match.awardPoint(to: .player1) }
        match.awardPoint(to: .player2)
        XCTAssertEqual(match.player2Score, 0)
        XCTAssertEqual(match.pointHistory.count, 11)
    }
}
