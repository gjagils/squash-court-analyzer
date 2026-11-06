import XCTest
import Foundation
@testable import SquashAnalyzerCore

final class CompetitionOverviewTests: XCTestCase {
    private let day = 24.0 * 3600.0
    // Noon, so an hour either way stays on the same day
    private let now = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!

    private func fixture(_ id: String, days: Double, home: String = "All Inn 8", away: String = "Delft 8") -> LeagueFixture {
        LeagueFixture(id: id, date: now.addingTimeInterval(days * day), home: home, away: away, score: nil,
                      url: URL(string: "https://sbn.toernooi.nl/\(id)")!)
    }

    private func ids(_ entries: [CompetitionEntry]) -> [String] {
        var result: [String] = []
        for entry in entries { result.append(entry.fixture?.id ?? entry.match?.home ?? "") }
        return result
    }

    func testTodayAndComingFirstThenThePastFromOldToRecent() {
        let overview = CompetitionOverview.make(matches: [], fixtures: [
            fixture("past-recent", days: -1.0), fixture("next-week", days: 7.0), fixture("past-old", days: -14.0),
            fixture("tomorrow", days: 1.0), fixture("today", days: 0.0)
        ], now: now)
        XCTAssertEqual(ids(overview.coming), ["today", "tomorrow", "next-week"])
        XCTAssertEqual(ids(overview.past), ["past-old", "past-recent"])
    }

    func testAMatchOfTodayStaysAboveTheLineAfterItsTime() {
        let earlier = fixture("today", days: 0.0)
        let overview = CompetitionOverview.make(matches: [], fixtures: [earlier], now: now.addingTimeInterval(3600.0))
        XCTAssertEqual(ids(overview.coming), ["today"])
        XCTAssertTrue(overview.past.isEmpty)
    }

    func testATeamMatchReplacesItsFixture() {
        let programme = [fixture("a", days: 1.0), fixture("b", days: -7.0, home: "Bevo 3", away: "All Inn 8"), fixture("c", days: 7.0)]
        let own = TeamMatch.from(fixture: programme[0], ownTeam: "All Inn 8")
        // Joined with a link before it took its fixture: found by day and teams
        let joined = TeamMatch(date: programme[1].date, home: "bevo 3", away: "All Inn 8", ownSide: TeamSide.away)
        let overview = CompetitionOverview.make(matches: [own, joined], fixtures: programme, now: now)
        XCTAssertEqual(overview.coming.count, 2)
        XCTAssertEqual(overview.coming[0].match?.id, own.id)
        XCTAssertEqual(overview.coming[1].fixture?.id, "c")
        XCTAssertEqual(overview.past.count, 1)
        XCTAssertEqual(overview.past[0].match?.id, joined.id)
    }

    func testAMatchTypedInWithoutProgrammeIsKept() {
        let typed = TeamMatch(date: now.addingTimeInterval(-3.0 * day), home: "X", away: "Y", ownSide: TeamSide.home)
        let overview = CompetitionOverview.make(matches: [typed], fixtures: [], now: now)
        XCTAssertEqual(overview.past.count, 1)
        XCTAssertFalse(overview.isEmpty)
        XCTAssertTrue(CompetitionOverview.make(matches: [], fixtures: [], now: now).isEmpty)
    }
}
