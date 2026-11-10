import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// Seizoensoverzicht per teamlid (4.0, T2)
final class TeamSeasonTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }

    private let seasonStart = Date(timeIntervalSince1970: 1_790_000_000.0)

    private func team(players: [LeaguePlayer]) -> LeagueTeamSnapshot {
        let fixture = LeagueFixture(id: "f1", date: seasonStart, home: "All Inn 8", away: "Delft 8", score: nil,
                                    url: URL(string: "https://sbn.toernooi.nl/league/x/team-match/1")!)
        return LeagueTeamSnapshot(source: URL(string: "https://sbn.toernooi.nl/league/x/team/8")!, name: "All Inn 8",
                                  competition: "Competitie", division: "3e klasse", rank: 1, played: 1, points: 10,
                                  fixtures: [fixture], players: players)
    }

    private func partij(_ slot: Int, _ name: String, _ scores: [(Int, Int)]) -> TeamPartij {
        var partij = TeamPartij(slot: slot, ownPlayer: name)
        for score in scores { XCTAssertTrue(partij.addGame(TeamGame(own: score.0, their: score.1))) }
        return partij
    }

    private func match(_ days: Double, _ partijen: [TeamPartij], own: String = "All Inn 8") -> TeamMatch {
        TeamMatch(date: seasonStart.addingTimeInterval(days * 86_400.0), home: own, away: "Delft 8", ownSide: .home,
                  fixtureId: nil, partijen: partijen)
    }

    func testParseRecord() {
        XCTAssertEqual(TeamSeason.parseRecord("3-1")?.0, 3)
        XCTAssertEqual(TeamSeason.parseRecord(" 0 - 2 ")?.1, 2)
        XCTAssertNil(TeamSeason.parseRecord(""))
        XCTAssertNil(TeamSeason.parseRecord("3"))
    }

    func testRowsCombineSbnAndTheApp() {
        let snapshot = team(players: [LeaguePlayer(id: "1", name: "Kees de Vries", record: "3-1"),
                                      LeaguePlayer(id: "2", name: "Paul Steenks", record: ""),
                                      LeaguePlayer(id: "1", name: "Kees de Vries", record: "3-1")])
        let matches = [
            match(7, [partij(1, "Kees de Vries", [(11, 5), (11, 6), (11, 7)]), partij(2, "Invaller Jan", [(5, 11), (11, 6), (6, 11), (7, 11)]),
                      partij(3, "kees  de vries", [(11, 5)])]),
            match(14, [partij(1, "Kees de Vries", [(5, 11), (11, 6), (6, 11), (7, 11)])]),
            // Another team, and last season: not counted
            match(7, [partij(1, "Kees de Vries", [(11, 5), (11, 6), (11, 7)])], own: "All Inn 3"),
            match(-30, [partij(1, "Kees de Vries", [(11, 5), (11, 6), (11, 7)])]),
        ]
        let rows = TeamSeason.rows(team: snapshot, matches: matches)
        XCTAssertEqual(rows.map { row in row.name }, ["Kees de Vries", "Paul Steenks", "Invaller Jan"])
        let kees = rows[0]
        XCTAssertEqual(kees.sbnText, "SBN 3-1")
        XCTAssertEqual(kees.won, 1)
        XCTAssertEqual(kees.lost, 1)
        XCTAssertEqual(kees.gamesWon, 4)
        XCTAssertEqual(kees.gamesLost, 3)
        XCTAssertEqual(kees.appText, "In de app: 2 partijen, 1-1 · games 4-3")
        XCTAssertFalse(rows[1].hasSbn)
        XCTAssertNil(rows[1].appText)
        XCTAssertFalse(rows[2].onTeamPage)
        XCTAssertEqual(rows[2].appText, "In de app: 1 partij, 0-1 · games 1-3")
    }
}
