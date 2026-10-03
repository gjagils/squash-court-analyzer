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
        // Wait for the end result, not the request: on Android the POST is
        // logged before `create` has finished and set the new link
        try await waitUntil { live.linkChanged }
        XCTAssertEqual(transport.requests[2].method, "POST")
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

// The share picture ("Deel als plaatje") follows the result card
final class ResultCardTests: XCTestCase {
    private func report(games: [MatchShareReport.Game], p1: Int, p2: Int, winner: Player?) -> MatchShareReport {
        MatchShareReport(player1Name: "Luis", player2Name: "Niels", bestOf: 5, firstGameNumber: 1,
                         player1Games: p1, player2Games: p2, matchWinner: winner, games: games,
                         startedAt: Date(), duration: 0.0)
    }

    private func game(_ number: Int, _ a: Int, _ b: Int, _ winner: Player?) -> MatchShareReport.Game {
        MatchShareReport.Game(number: number, player1Score: a, player2Score: b, winner: winner,
                              duration: nil, rallyWinners: [], strokes: 0)
    }

    func testMatchOver() {
        let games = [game(1, 15, 17, Player.player2), game(2, 11, 8, Player.player1), game(3, 11, 9, Player.player1),
                     game(4, 7, 11, Player.player2), game(5, 6, 11, Player.player2)]
        let card = ResultCard.from(report(games: games, p1: 2, p2: 3, winner: Player.player2))
        XCTAssertEqual(card.title, "WEDSTRIJD KLAAR")
        XCTAssertEqual(card.player1Score, 2)
        XCTAssertEqual(card.player2Score, 3)
        XCTAssertEqual(card.winnerText, "Niels wint de wedstrijd")
        XCTAssertEqual(card.chips.map { $0.label }, ["G1", "G2", "G3", "G4", "G5"])
        XCTAssertEqual(card.chips[0].score, "15-17")
        XCTAssertEqual(card.chips[1].winner, Player.player1)
    }

    func testGameJustWonShowsItsPoints() {
        let card = ResultCard.from(report(games: [game(1, 11, 8, Player.player1)], p1: 1, p2: 0, winner: nil))
        XCTAssertEqual(card.title, "GAME 1 KLAAR")
        XCTAssertEqual(card.player1Score, 11)
        XCTAssertEqual(card.player2Score, 8)
        XCTAssertEqual(card.winnerText, "Luis wint game 1")
    }

    func testDuringAGameShowsTheStand() {
        let card = ResultCard.from(report(games: [game(1, 11, 8, Player.player1), game(2, 4, 6, nil)], p1: 1, p2: 0, winner: nil))
        XCTAssertEqual(card.title, "TUSSENSTAND")
        XCTAssertEqual(card.player1Score, 1)
        XCTAssertEqual(card.winnerText, "Luis leidt 1-0")
        XCTAssertNil(card.chips[1].winner)
    }
}
