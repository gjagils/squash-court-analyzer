import XCTest
import Foundation
@testable import SquashAnalyzerCore

// The official intervals for the referee (3.2): WSF Rules of Singles Squash
// 2025, rule 4.1 (warm-up 4 minutes, sides after 2) and 7.1 (1 minute to the
// start, 2 minutes between games), with "15 seconds" and "Time".
final class RefereeIntervalTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_790_000_000)

    func at(_ seconds: Double) -> Date { start.addingTimeInterval(seconds) }

    func testTheWarmUpCallsHalfTimeFifteenSecondsAndTime() {
        let warmup = RefereeInterval(kind: RefereeIntervalKind.warmup, startedAt: start)
        XCTAssertEqual(warmup.remaining(at: at(0)), 240)
        XCTAssertNil(warmup.call(at: at(119)))
        XCTAssertEqual(warmup.call(at: at(120)), RefereeCall.halfTime)
        XCTAssertEqual(warmup.call(at: at(224)), RefereeCall.halfTime)
        XCTAssertEqual(warmup.call(at: at(225)), RefereeCall.fifteenSeconds)
        XCTAssertEqual(warmup.call(at: at(240)), RefereeCall.time)
        XCTAssertEqual(warmup.remaining(at: at(300)), 0)
    }

    func testTheBreakBetweenGamesHasNoHalfTime() {
        let pause = RefereeInterval(kind: RefereeIntervalKind.betweenGames, startedAt: start)
        XCTAssertNil(pause.call(at: at(60)))
        XCTAssertEqual(pause.call(at: at(105)), RefereeCall.fifteenSeconds)
        XCTAssertEqual(pause.call(at: at(120)), RefereeCall.time)
        XCTAssertEqual(RefereeInterval.clockText(125), "2:05")
        XCTAssertEqual(RefereeInterval.clockText(9), "0:09")
    }

    func testTheWarmUpRunsIntoTheMinuteToTheStartAndTheFirstRallyEndsIt() {
        let match = RefereeMatch(player1Name: "Bas", player2Name: "Tim", bestOf: 5, startingServer: Player.player1, matchStartedAt: start)
        XCTAssertTrue(match.isBeforeFirstRally)
        XCTAssertNil(match.runningInterval(at: at(10)))
        match.warmupStartedAt = start
        XCTAssertEqual(match.runningInterval(at: at(100))?.kind, RefereeIntervalKind.warmup)
        let toStart = match.runningInterval(at: at(250))
        XCTAssertEqual(toStart?.kind, RefereeIntervalKind.toStart)
        XCTAssertEqual(toStart?.remaining(at: at(250)), 50)
        match.awardPoint(to: Player.player1)
        XCTAssertNil(match.runningInterval(at: at(260)))
    }

    func testTwoMinutesBetweenGamesFromTheLastRally() {
        var clock = start
        let match = RefereeMatch(player1Name: "Bas", player2Name: "Tim", bestOf: 5, startingServer: Player.player1, matchStartedAt: start)
        match.now = { clock }
        for _ in 0..<11 { match.awardPoint(to: Player.player1) }
        clock = at(30)
        match.confirmNextGame()
        let pause = match.runningInterval(at: at(40))
        XCTAssertEqual(pause?.kind, RefereeIntervalKind.betweenGames)
        XCTAssertEqual(pause?.remaining(at: at(40)), 80)
        match.awardPoint(to: Player.player2)
        XCTAssertNil(match.runningInterval(at: at(50)))
    }
}
