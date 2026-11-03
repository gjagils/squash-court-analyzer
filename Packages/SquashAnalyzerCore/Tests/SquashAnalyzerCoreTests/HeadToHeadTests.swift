import XCTest
import Foundation
@testable import SquashAnalyzerCore

// "3-1 tegen Bas" at Kies speler (3.2): finished matches between two names.
final class HeadToHeadTests: XCTestCase {
    func match(_ p1: String, _ p2: String, _ g1: Int, _ g2: Int) -> MatchHistorySummary {
        MatchHistorySummary(id: UUID().uuidString, kind: "coach", player1Name: p1, player2Name: p2,
                            player1Games: g1, player2Games: g2, status: "finished", updatedAt: Date())
    }

    func testBothOrdersCountAndUnfinishedMatchesDoNot() {
        let history = [
            match("Tim", "Bas", 3, 1),
            match("bas", "tim ", 3, 0),
            match("Tim", "Bas", 2, 3),
            match("Tim", "Bas", 1, 1),
            match("Tim", "Piet", 3, 0),
        ]
        let record = HeadToHead.record(of: "Tim", against: "Bas", in: history)
        XCTAssertEqual(record, HeadToHead(wins: 1, losses: 2))
        XCTAssertEqual(record.text(against: "Bas"), "1-2 tegen Bas")
        XCTAssertEqual(HeadToHead.record(of: "Bas", against: "Tim", in: history), HeadToHead(wins: 2, losses: 1))
    }

    func testNoRecordWithoutAnOpponent() {
        let history = [match("Tim", "Bas", 3, 1)]
        XCTAssertEqual(HeadToHead.record(of: "Tim", against: "", in: history).played, 0)
        XCTAssertEqual(HeadToHead.record(of: "Tim", against: "tim", in: history).played, 0)
    }
}
