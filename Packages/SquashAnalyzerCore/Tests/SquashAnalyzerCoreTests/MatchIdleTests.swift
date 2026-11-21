import XCTest
import Foundation
@testable import SquashAnalyzerCore

final class MatchIdleTests: XCTestCase {
    func testAMatchLeftAloneForAnHourIsIdle() {
        let defaults = UserDefaults(suiteName: "match-idle-\(UUID().uuidString)")!
        let id = UUID()
        let start = Date(timeIntervalSince1970: 1_793_181_600.0)
        XCTAssertFalse(MatchIdle.isIdle(id, kind: MatchIdle.coach, now: start, defaults: defaults), "no note: nothing is known")
        MatchIdle.touch(id, kind: MatchIdle.coach, now: start, defaults: defaults)
        XCTAssertFalse(MatchIdle.isIdle(id, kind: MatchIdle.coach, now: start.addingTimeInterval(59.0 * 60.0), defaults: defaults))
        XCTAssertTrue(MatchIdle.isIdle(id, kind: MatchIdle.coach, now: start.addingTimeInterval(61.0 * 60.0), defaults: defaults))
        XCTAssertFalse(MatchIdle.isIdle(UUID(), kind: MatchIdle.coach, now: start.addingTimeInterval(7200.0), defaults: defaults),
                       "the note is about another match")
        XCTAssertFalse(MatchIdle.isIdle(id, kind: MatchIdle.referee, now: start.addingTimeInterval(7200.0), defaults: defaults),
                       "coach and referee each have their own")
        // A point after a long break makes it open again
        MatchIdle.touch(id, kind: MatchIdle.coach, now: start.addingTimeInterval(7200.0), defaults: defaults)
        XCTAssertFalse(MatchIdle.isIdle(id, kind: MatchIdle.coach, now: start.addingTimeInterval(7300.0), defaults: defaults))
    }
}
