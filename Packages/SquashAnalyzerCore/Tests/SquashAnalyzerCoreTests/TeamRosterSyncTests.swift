import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// The players of Mijn team into Spelers, marked "In mijn team", once per team link
final class TeamRosterSyncTests: XCTestCase {
    private final class MemoryStore: PlayerProfileStore, @unchecked Sendable {
        var players: [PlayerProfile]
        init(_ players: [PlayerProfile] = []) { self.players = players }
        func loadPlayers() async throws -> [PlayerProfile] { players }
        func savePlayer(_ player: PlayerProfile) async throws { players.append(player) }
        func deletePlayer(_ id: String) async throws { players = players.filter { other in other.id != id } }
    }

    private func defaults() -> UserDefaults {
        let suite = "rostersync-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    private func snapshot(_ names: [String], link: String = "https://sbn.toernooi.nl/team/1") -> LeagueTeamSnapshot {
        var players: [LeaguePlayer] = []
        for (index, name) in names.enumerated() { players.append(LeaguePlayer(id: "p\(index)", name: name, record: "1-0")) }
        return LeagueTeamSnapshot(source: URL(string: link)!, name: "All Inn Squash 8", competition: "SBN", division: "1e klasse",
                                  rank: 1, played: 1, points: 3, fixtures: [], players: players)
    }

    @MainActor
    func testNewPlayersAreMadeAndMarkedAndAnExistingOneOnlyGetsTheMark() async {
        let defaults = defaults()
        let existing = PlayerProfile(name: "Gerd-Jan", coachingNotes: "Linkshandig")
        let store = MemoryStore([existing])
        let added = await TeamRosterSync.run(snapshot(["gerd-jan", "Gerrie Ananias"]), store: store, in: defaults)
        XCTAssertEqual(added, 1)
        XCTAssertEqual(store.players.count, 2)
        XCTAssertEqual(store.players[0].coachingNotes, "Linkshandig", "the existing player is untouched")
        let ids = TeamRoster.ids(in: defaults)
        XCTAssertEqual(ids.count, 2)
        XCTAssertTrue(ids.contains(existing.id))
    }

    @MainActor
    func testItRunsOncePerTeamLink() async {
        let defaults = defaults()
        let store = MemoryStore()
        let first = await TeamRosterSync.run(snapshot(["Piet"]), store: store, in: defaults)
        XCTAssertEqual(first, 1)
        // The player was deleted on purpose: the same link does not bring him back
        store.players = []
        let again = await TeamRosterSync.run(snapshot(["Piet"]), store: store, in: defaults)
        XCTAssertEqual(again, 0)
        XCTAssertTrue(store.players.isEmpty)
        // Another team link runs again
        let other = await TeamRosterSync.run(snapshot(["Piet"], link: "https://sbn.toernooi.nl/team/2"), store: store, in: defaults)
        XCTAssertEqual(other, 1)
    }
}
