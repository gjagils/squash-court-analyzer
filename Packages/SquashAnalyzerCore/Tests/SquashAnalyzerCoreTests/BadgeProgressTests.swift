import XCTest
import Foundation
@testable import SquashAnalyzerCore

// "Nog 3 tot zilver" (3.2): the running number of a career badge against its next tier.
final class BadgeProgressTests: XCTestCase {
    // After any badge reset start (BadgeSeason), as in BadgeEngineTests
    let start = Date(timeIntervalSince1970: 1_900_000_000)

    func matches(_ results: [Bool], points: Int = 30) -> [BadgeEngine.CareerMatch] {
        var list: [BadgeEngine.CareerMatch] = []
        var index = 0
        for won in results {
            list.append(BadgeEngine.CareerMatch(matchId: UUID(), date: start.addingTimeInterval(Double(index) * 3600.0),
                                                won: won, pointsWon: points, opponentKey: "piet"))
            index += 1
        }
        return list
    }

    func progress(_ family: BadgeKind, in list: [BadgeProgress]) -> BadgeProgress? {
        for item in list where item.family == family { return item }
        return nil
    }

    func testEachCareerBadgeCountsItsOwnNumber() {
        // 7 wins, 2 losses, the last 2 won: 9 matches, 270 points
        let list = BadgeProgress.of(history: matches([true, true, true, true, true, false, false, true, true]))
        XCTAssertEqual(progress(BadgeKind.veteran, in: list)?.remaining, 16)
        XCTAssertEqual(progress(BadgeKind.tenOutOfTen, in: list)?.remaining, 3)
        XCTAssertEqual(progress(BadgeKind.centurion, in: list)?.next, BadgeKind.centurionSilver)
        XCTAssertEqual(progress(BadgeKind.centurion, in: list)?.remaining, 230)
        XCTAssertEqual(progress(BadgeKind.hatTrick, in: list)?.remaining, 1)
        XCTAssertNil(progress(BadgeKind.nemesis, in: list))
    }

    func testTheTextNamesTheTier() {
        let item = BadgeProgress(family: BadgeKind.tenOutOfTen, next: BadgeKind.tenOutOfTenSilver, current: 22)
        XCTAssertEqual(item.text, "Nog 3 tot zilver")
    }

    func testNoEntryOnceTheHighestTierIsReached() {
        let list = BadgeProgress.of(history: matches(Array(repeating: true, count: 100), points: 11))
        XCTAssertNil(progress(BadgeKind.veteran, in: list))
        XCTAssertNil(progress(BadgeKind.tenOutOfTen, in: list))
        XCTAssertNil(progress(BadgeKind.hatTrick, in: list))
        // 1100 points: past gold too
        XCTAssertNil(progress(BadgeKind.centurion, in: list))
    }
}
