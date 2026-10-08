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
}
