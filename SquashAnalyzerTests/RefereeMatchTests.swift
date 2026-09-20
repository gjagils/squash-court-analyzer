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

    func testOverrideBecomesThatPlayersHandOutBoxForTheMatch() {
        let match = makeMatch()                 // A serves, right
        match.overrideSide(to: .left)           // left-handed A starts left
        XCTAssertEqual(match.preferredSide(for: .player1), .left)
        XCTAssertNil(match.preferredSide(for: .player2))

        match.awardPoint(to: .player1)          // A keeps serving, alternates to right
        XCTAssertEqual(match.serverSide, .right)
        match.awardPoint(to: .player2)          // hand-out to B: B has no preference
        XCTAssertEqual(match.serverSide, .right)
        match.awardPoint(to: .player1)          // hand-out back to A: starts left again
        XCTAssertEqual(match.currentServer, .player1)
        XCTAssertEqual(match.serverSide, .left)
        XCTAssertEqual(match.pointHistory.last?.label, "2L")
    }

    func testPreferredBoxIsUsedWhenWinnerServesNextGame() {
        let match = makeMatch(startingServer: .player1)
        match.awardPoint(to: .player2)          // B takes service
        match.overrideSide(to: .left)           // B prefers left
        for _ in 0..<10 { match.awardPoint(to: .player2) }
        XCTAssertEqual(match.currentGameWinner, .player2)

        match.confirmNextGame()
        XCTAssertEqual(match.currentServer, .player2)
        XCTAssertEqual(match.serverSide, .left)
        XCTAssertEqual(match.preferredSide(for: .player2), .left)
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
        XCTAssertNil(match.preferredSide(for: .player2))
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

    func testMatchResultCountsTheUnconfirmedFinalGame() {
        let match = makeMatch()
        for _ in 0..<2 {
            for _ in 0..<11 { match.awardPoint(to: .player1) }
            match.confirmNextGame()
        }
        XCTAssertEqual(match.player1GamesWon, 2)
        XCTAssertFalse(match.isMatchOver)

        for _ in 0..<11 { match.awardPoint(to: .player1) }
        XCTAssertTrue(match.isMatchOver)
        XCTAssertEqual(match.matchWinner, .player1)
        XCTAssertEqual(match.player1TotalGames, 3)
        XCTAssertEqual(match.player2TotalGames, 0)
        XCTAssertTrue(match.whatsAppText.contains("3 – 0"))
        XCTAssertEqual(match.allGameResults.count, 3)
    }

    func testNoPointsAfterGameIsOver() {
        let match = makeMatch()
        for _ in 0..<11 { match.awardPoint(to: .player1) }
        match.awardPoint(to: .player2)
        XCTAssertEqual(match.player2Score, 0)
        XCTAssertEqual(match.pointHistory.count, 11)
    }
    func testShareTextsCoverAllGamesAndTheWinner() {
        let match = makeMatch()
        // A = player 1, B = player 2. G1: 11-3 with one stroke for A, G2: 5-11, G3 in progress 4-2
        for _ in 0..<10 { match.awardPoint(to: .player1) }
        for _ in 0..<3 { match.awardPoint(to: .player2) }
        match.awardPoint(to: .player1, isStroke: true)
        match.confirmNextGame()
        for _ in 0..<5 { match.awardPoint(to: .player1) }
        for _ in 0..<11 { match.awardPoint(to: .player2) }
        match.confirmNextGame()
        for _ in 0..<4 { match.awardPoint(to: .player1) }
        for _ in 0..<2 { match.awardPoint(to: .player2) }

        XCTAssertEqual(match.gameSummaries.count, 3)
        XCTAssertNil(match.gameSummaries[2].winner)
        XCTAssertEqual(match.totalStrokes, 1)
        XCTAssertEqual(match.totalRallies, 14 + 16 + 6)
        XCTAssertEqual(match.longestRun?.length, 11)
        XCTAssertEqual(match.longestRun?.player, .player2)
        XCTAssertNotNil(match.completedGames[0].duration)
        XCTAssertEqual(match.completedGames[0].points.count, 14)

        let compact = match.shareText(style: .compact)
        XCTAssertTrue(compact.contains("11-3 · 5-11 · 4-2…"))
        XCTAssertTrue(compact.contains("A 1 – 1 B"))

        let card = match.shareText(style: .scorecard)
        XCTAssertTrue(card.contains("```"))
        XCTAssertTrue(card.contains("G1"))
        XCTAssertTrue(card.contains("Stand: gelijk 1 – 1"))

        let report = match.shareText(style: .report)
        XCTAssertTrue(report.contains("*Game 1* · 11-3 · ✅ A"))
        XCTAssertTrue(report.contains("1 stroke"))
        XCTAssertTrue(report.contains("*Game 3* · 4-2 · bezig"))
        XCTAssertTrue(report.contains("langste reeks 11 (B)"))

        // Finish the match: A wins 3-1
        for _ in 0..<7 { match.awardPoint(to: .player1) }
        match.confirmNextGame()
        for _ in 0..<11 { match.awardPoint(to: .player1) }
        XCTAssertTrue(match.isMatchOver)
        XCTAssertTrue(match.shareText(style: .compact).contains("🏆 *A* 3 – 1 B"))
        XCTAssertTrue(match.shareText(style: .report).contains("🏆 *A wint met 3–1*"))
    }

    func testHeadStartStartsAtLaterGameAndCountsTowardsTheMatch() {
        let match = RefereeMatch(player1Name: "A", player2Name: "B", bestOf: 5, startingServer: .player2,
                                 player1GamesBefore: 0, player2GamesBefore: 2)
        XCTAssertEqual(match.currentGameNumber, 3)
        XCTAssertEqual(match.player2GamesWon, 2)
        XCTAssertEqual(match.player1GamesWon, 0)
        XCTAssertFalse(match.isMatchOver)

        for _ in 0..<11 { match.awardPoint(to: .player1) }
        XCTAssertFalse(match.isMatchOver)
        XCTAssertEqual(match.player1TotalGames, 1)
        XCTAssertTrue(match.shareText(style: .compact).contains("vanaf game 3"))
        XCTAssertTrue(match.shareText(style: .compact).contains("A 1 – 2 *B*"))
        match.confirmNextGame()
        XCTAssertEqual(match.currentGameNumber, 4)

        for _ in 0..<11 { match.awardPoint(to: .player2) }
        XCTAssertTrue(match.isMatchOver)
        XCTAssertEqual(match.matchWinner, .player2)
        XCTAssertEqual(match.allGameResults.map(\.number), [3, 4])

        // A stand that already decides the match falls back to a full match
        let invalid = RefereeMatch(player1Name: "A", player2Name: "B", bestOf: 3, startingServer: .player1,
                                   player1GamesBefore: 2, player2GamesBefore: 0)
        XCTAssertEqual(invalid.currentGameNumber, 1)
    }

    func testUndoRestoresLastPointTimestamp() {
        let match = makeMatch()
        XCTAssertNil(match.lastPointAt)
        match.awardPoint(to: .player1)
        XCTAssertNotNil(match.lastPointAt)
        match.undo()
        XCTAssertNil(match.lastPointAt)
    }
}
