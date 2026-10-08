import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// "Eigen" or "gedeeld" on a team match, and putting it on the live page in one go
final class TeamShareTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_793_181_600.0)

    private func team() -> TeamMatch {
        TeamMatch(date: day, home: "All Inn Squash 8", away: "Squash Delft 8", ownSide: .home)
    }

    func testAMatchWithoutALivePageIsOwnAndCountsNothing() {
        let match = team()
        XCTAssertFalse(match.isLive)
        XCTAssertEqual(match.teammatePartijen, 0)
        XCTAssertEqual(match.ownPartijen, 0)
        XCTAssertFalse(match.needsOwnPartij)
    }

    func testPartijenFromTeammatesAreCountedApartFromOurOwn() {
        var match = team()
        match.liveId = "abcdefghjkmn"
        match.liveKey = "K3yK3yK3yK3yK3yK3yK3yK3y"
        var mine = TeamPartij(slot: 1, ownPlayer: "Jan", opponentPlayer: "Piet", games: [TeamGame(own: 11, their: 3)])
        mine.fromLive = nil
        var theirs = TeamPartij(slot: 2, ownPlayer: "Kees", opponentPlayer: "Klaas", games: [TeamGame(own: 11, their: 5)])
        theirs.fromLive = true
        match.partijen[0] = mine
        match.partijen[1] = theirs
        XCTAssertEqual(match.ownPartijen, 1)
        XCTAssertEqual(match.teammatePartijen, 1)
    }

    func testAJoinedPhoneWithNothingOfItsOwnIsToldWhatToDo() {
        var match = team()
        match.liveId = "abcdefghjkmn"
        match.liveKey = "K3yK3yK3yK3yK3yK3yK3yK3y"
        XCTAssertTrue(match.needsOwnPartij, "joined (no owner key), nothing of ours yet")
        match.liveOwnerKey = "0wn3r0wn3r0wn3r0wn3r0wn3r"
        XCTAssertFalse(match.needsOwnPartij, "the phone that started it needs no hint")
    }

    @MainActor
    func testGoLiveKeepsTheKeysAndSendsWhatIsFilledIn() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("teamshare-\(UUID().uuidString)")
        let store = JSONFileTeamMatchStore(directory: directory)
        let transport = FakeTeamTransport()
        let live = TeamLive(transport: transport)
        live.baseURL = "https://live.test"
        var match = team()
        var partij = TeamPartij(slot: 1, ownPlayer: "Jan", opponentPlayer: "Piet")
        XCTAssertTrue(partij.addGame(TeamGame(own: 11, their: 4)))
        match.update(partij)
        try await store.save(match)

        let shared = try await TeamMatchSupport.goLive(match, store: store, live: live)
        XCTAssertTrue(shared.isLive)
        XCTAssertTrue(shared.isLiveOwner)
        XCTAssertEqual(shared.liveId, "abcdefghjkmn")
        let stored = try await store.loadAll()
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].liveId, "abcdefghjkmn")
        XCTAssertEqual(stored[0].liveOwnerKey, "0wn3r0wn3r0wn3r0wn3r0wn3r")
        let puts = transport.requests.filter { request in request.method == "PUT" }
        XCTAssertEqual(puts.count, 1, "the one partij that is filled in")
    }

    @MainActor
    func testGoLiveWithoutConnectionLeavesTheMatchAsItWas() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("teamshare-\(UUID().uuidString)")
        let store = JSONFileTeamMatchStore(directory: directory)
        let transport = FakeTeamTransport()
        transport.offline = true
        let live = TeamLive(transport: transport)
        live.baseURL = "https://live.test"
        let match = team()
        try await store.save(match)
        do {
            _ = try await TeamMatchSupport.goLive(match, store: store, live: live)
            XCTFail("no connection: it must throw")
        } catch { }
        let stored = try await store.loadAll()
        XCTAssertFalse(stored[0].isLive)
    }

    // MARK: Uitnodiging voor een avond die we al hebben

    private let invite = TeamInvite(id: "abcdefghjkmn", key: "K3yK3yK3yK3yK3yK3yK3y_-9")

    private func page() -> TeamLiveState {
        let json = """
        {"team":{"home":"All Inn Squash 8","away":"Squash Delft 8","date":1793181600000},
         "partijen":{"2":{"p1":"Piet","p2":"Jan","bestOf":5,"games":[[11,9],[4,11]],"score":[3,5],"gamesWon":[1,1],"server":1,"side":"R","status":"playing"}},
         "updatedAt":1793181700000}
        """
        return try! JSONDecoder().decode(TeamLiveState.self, from: json.data(using: String.Encoding.utf8)!)
    }

    func testAnEmptyMatchOfOursIsLinkedAndKeepsItsSide() {
        let mine = TeamMatch(date: day, home: "All Inn Squash 8", away: "squash delft 8", ownSide: .away, fixtureId: "f1")
        guard case TeamJoinTwin.empty(let found) = TeamMatch.twin(of: page(), in: [mine]) else { return XCTFail("empty twin expected") }
        let linked = found.linked(to: page(), invite: invite)
        XCTAssertEqual(linked.id, mine.id)
        XCTAssertEqual(linked.ownSide, TeamSide.away, "the sharer's side is not taken over")
        XCTAssertEqual(linked.fixtureId, "f1")
        XCTAssertEqual(linked.liveId, invite.id)
        XCTAssertEqual(linked.liveKey, invite.key)
        XCTAssertNil(linked.liveOwnerKey)
        XCTAssertEqual(linked.partij(2).fromLive, true)
    }

    func testAMatchWithGamesAsksAndTakingOverReplacesOurPartijen() {
        var mine = TeamMatch(date: day, home: "All Inn Squash 8", away: "Squash Delft 8", ownSide: .home)
        var partij = TeamPartij(slot: 1, ownPlayer: "Kees", opponentPlayer: "Klaas")
        XCTAssertTrue(partij.addGame(TeamGame(own: 11, their: 3)))
        mine.update(partij)
        guard case TeamJoinTwin.filled(let found) = TeamMatch.twin(of: page(), in: [mine]) else { return XCTFail("filled twin expected") }
        let taken = found.takingOver(page(), invite: invite)
        XCTAssertEqual(taken.id, mine.id)
        XCTAssertEqual(taken.ownSide, TeamSide.home)
        XCTAssertFalse(taken.partij(1).hasEntry, "our own partij is gone")
        XCTAssertEqual(taken.partij(2).games.count, 2, "the page's partij came in")
        XCTAssertTrue(taken.isLive)
    }

    func testAnotherDayOrAnotherTeamIsNoTwin() {
        let later = TeamMatch(date: day.addingTimeInterval(3 * 86_400), home: "All Inn Squash 8", away: "Squash Delft 8", ownSide: .home)
        let other = TeamMatch(date: day, home: "All Inn Squash 8", away: "Squash Leiden 3", ownSide: .home)
        guard case TeamJoinTwin.none = TeamMatch.twin(of: page(), in: [later, other]) else { return XCTFail("no twin expected") }
    }

    func testATwinWithAnotherLivePageIsRefused() {
        var mine = TeamMatch(date: day, home: "All Inn Squash 8", away: "Squash Delft 8", ownSide: .home)
        mine.liveId = "zzzzzzzzzzzz"
        mine.liveKey = "K3yK3yK3yK3yK3yK3yK3yK3y"
        guard case TeamJoinTwin.sharedElsewhere = TeamMatch.twin(of: page(), in: [mine]) else { return XCTFail("refusal expected") }
    }
}
