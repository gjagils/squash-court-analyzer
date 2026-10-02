import XCTest
import Foundation
@testable import SquashAnalyzerCore

// Live meekijken: only first names leave the phone, the whole state goes
// after every rally, and the session is deleted as soon as the match is over.
final class LiveShareTests: XCTestCase {

    // MARK: - Snapshot

    func testFirstNameOnly() {
        XCTAssertEqual(LiveSnapshot.firstName("Jan de Vries", fallback: "x"), "Jan")
        XCTAssertEqual(LiveSnapshot.firstName("  Anne-Marie Jansen", fallback: "x"), "Anne-Marie")
        XCTAssertEqual(LiveSnapshot.firstName("   ", fallback: "Speler 1"), "Speler 1")
        XCTAssertEqual(LiveSnapshot.firstName("Maximiliaan-Alexander-Theodoor", fallback: "x").count, LiveSnapshot.maxNameLength)
    }

    func testCoachSnapshotFollowsTheMatch() throws {
        let match = Match()
        match.player1Name = "Gerd-Jan van Gils"
        match.player2Name = "Paul Steenks"
        XCTAssertEqual(match.liveSnapshot().status, LiveStatus.warmup)
        XCTAssertEqual(match.liveSnapshot().p1, "Gerd-Jan")
        XCTAssertEqual(match.liveSnapshot().p2, "Paul")

        let game = match.currentGame
        game.start()
        XCTAssertEqual(match.liveSnapshot().status, LiveStatus.playing)
        game.addPoint(to: Player.player2, pointType: PointType.winner, at: CourtZone.frontLeft, with: ShotType.drop, isVolley: true)
        let snapshot = match.liveSnapshot(showLastPoint: true)
        XCTAssertEqual(snapshot.score, [0, 1])
        XCTAssertEqual(snapshot.server, 2)
        XCTAssertEqual(snapshot.side, "R")
        XCTAssertEqual(snapshot.lastPoint, "Paul: Winner · Volley drop · Voor Links")
        XCTAssertNil(match.liveSnapshot().lastPoint, "the last point only when the coach shows it")

        for _ in 0..<11 {
            game.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        }
        XCTAssertEqual(match.liveSnapshot().status, LiveStatus.between)
        XCTAssertEqual(match.liveSnapshot().games, [[11, 1]])
        XCTAssertEqual(match.liveSnapshot().gamesWon, [1, 0])

        let json = String(data: try JSONEncoder().encode(match.liveSnapshot(showLastPoint: true)), encoding: String.Encoding.utf8) ?? ""
        XCTAssertFalse(json.contains("Gils"), "no surnames on the server")
        XCTAssertFalse(json.contains("Steenks"))
    }

    func testRefereeSnapshot() {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        XCTAssertEqual(match.liveSnapshot.status, LiveStatus.warmup)
        XCTAssertEqual(match.liveSnapshot.bestOf, 5)
        XCTAssertEqual(match.liveSnapshot.server, 1)
    }

    // MARK: - Sending

    @MainActor
    func testStartUpdateFinishDeletesTheSession() async throws {
        let transport = FakeLiveTransport()
        let live = LiveShare(transport: transport)
        live.baseURL = "https://live.test"
        let match = Match()
        match.player1Name = "Jan"
        match.player2Name = "Piet"

        let link = try await live.start(matchId: match.id, snapshot: match.liveSnapshot())
        XCTAssertEqual(link, "https://live.test/l/abc")
        XCTAssertTrue(live.isLive(match.id))
        XCTAssertEqual(transport.requests.last?.method, "POST")

        match.currentGame.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        live.update(matchId: match.id, snapshot: match.liveSnapshot())
        try await waitUntil { transport.requests.count >= 2 }
        XCTAssertEqual(transport.requests[1].method, "PUT")
        XCTAssertEqual(transport.requests[1].url, "https://live.test/api/live/abc")
        XCTAssertEqual(transport.requests[1].headers["Authorization"], "Bearer key")

        // Another match's update is never sent
        live.update(matchId: UUID(), snapshot: match.liveSnapshot())

        await live.finish(matchId: match.id, snapshot: match.liveSnapshot())
        try await waitUntil { transport.requests.last?.method == "DELETE" }
        XCTAssertEqual(transport.requests.map { $0.method }, ["POST", "PUT", "PUT", "DELETE"])
        XCTAssertFalse(live.isLive(match.id))
        XCTAssertNil(live.link)
    }

    @MainActor
    func testALostSessionIsMadeAgainWithANewLink() async throws {
        let transport = FakeLiveTransport()
        let live = LiveShare(transport: transport)
        let match = Match()
        _ = try await live.start(matchId: match.id, snapshot: match.liveSnapshot())
        transport.putStatus = 404
        transport.nextId = "def"
        live.update(matchId: match.id, snapshot: match.liveSnapshot())
        try await waitUntil { transport.requests.count >= 3 }
        XCTAssertEqual(transport.requests[2].method, "POST")
        XCTAssertTrue(live.linkChanged)
        XCTAssertEqual(live.link, LiveShare.defaultBaseURL + "/l/def")
    }

    @MainActor
    func testNoNetworkKeepsTheStateForTheNextRally() async throws {
        let transport = FakeLiveTransport()
        let live = LiveShare(transport: transport)
        let match = Match()
        _ = try await live.start(matchId: match.id, snapshot: match.liveSnapshot())
        transport.offline = true
        live.update(matchId: match.id, snapshot: match.liveSnapshot())
        try await waitUntil { live.offline }
        transport.offline = false
        live.update(matchId: match.id, snapshot: match.liveSnapshot())
        try await waitUntil { !live.offline }
        XCTAssertEqual(transport.requests.last?.method, "PUT")
    }

    @MainActor
    func testWithoutAServerStartingFails() async {
        let live = LiveShare(transport: nil)
        do {
            _ = try await live.start(matchId: UUID(), snapshot: Match().liveSnapshot())
            XCTFail("no transport")
        } catch {
            XCTAssertEqual(error as? LiveShareError, LiveShareError.noTransport)
        }
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async throws {
        var tries = 0
        while !condition() && tries < 200 {
            tries += 1
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), "timed out")
    }
}

struct LiveRequest {
    let method: String
    let url: String
    let headers: [String: String]
}

final class FakeLiveTransport: LiveTransport, @unchecked Sendable {
    var requests: [LiveRequest] = []
    var putStatus = 204
    var nextId = "abc"
    var offline = false

    func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> AITransportResponse {
        if offline { throw URLError(.notConnectedToInternet) }
        requests.append(LiveRequest(method: method, url: url.absoluteString, headers: headers))
        if method == "POST" {
            let base = url.absoluteString.replacingOccurrences(of: "/api/live", with: "")
            let json = "{\"id\":\"\(nextId)\",\"writeKey\":\"key\",\"url\":\"\(base)/l/\(nextId)\"}"
            return AITransportResponse(status: 201, body: json.data(using: String.Encoding.utf8) ?? Data())
        }
        if method == "PUT" { return AITransportResponse(status: putStatus, body: Data()) }
        return AITransportResponse(status: 204, body: Data())
    }
}
