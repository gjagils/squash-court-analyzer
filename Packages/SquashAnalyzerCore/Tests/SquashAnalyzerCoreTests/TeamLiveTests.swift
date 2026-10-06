import Foundation
import XCTest
@testable import SquashAnalyzerCore

struct TeamRequest {
    let method: String
    let url: String
    let key: String
    let body: String
}

/// Plays the server: records every request with its body, answers a POST with
/// a team match and a GET with a canned state
final class FakeTeamTransport: LiveTransport, @unchecked Sendable {
    var requests: [TeamRequest] = []
    var putStatus = 204
    var getStatus = 200
    var getBody = ""
    var offline = false

    func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> AITransportResponse {
        if offline { throw URLError(.notConnectedToInternet) }
        let text = body.flatMap { String(data: $0, encoding: String.Encoding.utf8) } ?? ""
        let auth = headers["Authorization"] ?? ""
        requests.append(TeamRequest(method: method, url: url.absoluteString, key: auth, body: text))
        if method == "POST" {
            let json = "{\"id\":\"abcdefghjkmn\",\"writeKey\":\"K3yK3yK3yK3yK3yK3yK3yK3y\",\"url\":\"https://live.test/t/abcdefghjkmn\"}"
            return AITransportResponse(status: 201, body: json.data(using: String.Encoding.utf8) ?? Data())
        }
        if method == "GET" { return AITransportResponse(status: getStatus, body: getBody.data(using: String.Encoding.utf8) ?? Data()) }
        if method == "PUT" { return AITransportResponse(status: putStatus, body: Data()) }
        return AITransportResponse(status: 204, body: Data())
    }
}

/// Live teams matches (Competitie): the payload per partij, the invitation, the live service
final class TeamLiveTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_793_181_600.0)

    private func team(ownSide: TeamSide = .home) -> TeamMatch {
        TeamMatch(date: day, home: "All Inn Squash 8", away: "Squash Delft 8", ownSide: ownSide)
    }

    private func snapshot(_ p1: String, _ p2: String, score: [Int], games: [[Int]] = [], won: [Int] = [0, 0],
                          server: Int = 1, status: LiveStatus = LiveStatus.playing, winner: Int? = nil) -> LiveSnapshot {
        LiveSnapshot(p1: p1, p2: p2, bestOf: 5, games: games, score: score, gamesWon: won, server: server, side: "R",
                     status: status, lastPoint: "Jan: Winner", winner: winner)
    }

    @MainActor private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        var tries = 0
        while !condition() && tries < 300 {
            tries += 1
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition(), "timed out")
    }

    // MARK: Standaardnamen

    func testWithoutNamesTheDefaultIsTheTeamAndTheSlot() {
        let match = team()
        let partij = match.partij(1)
        XCTAssertEqual(match.ownDisplayName(partij), "All Inn Squash 8 E1")
        XCTAssertEqual(match.opponentDisplayName(partij), "Squash Delft 8 E1")
        let away = team(ownSide: .away)
        XCTAssertEqual(away.ownDisplayName(away.partij(3)), "Squash Delft 8 E3")
        // The report and the scorecard use them instead of question marks
        var played = TeamPartij(slot: 1)
        XCTAssertTrue(played.addGame(TeamGame(own: 11, their: 8)))
        var withGame = match
        withGame.update(played)
        let report = TeamMatchReport.text(withGame, style: MatchShareStyle.report)
        XCTAssertTrue(report.contains("All Inn Squash 8 E1 – Squash Delft 8 E1 · 1-0 (11-8)"), report)
        XCTAssertTrue(report.contains("*E2* nog niet gespeeld"), report)
        let card = TeamMatchReport.text(withGame, style: MatchShareStyle.scorecard)
        XCTAssertTrue(card.contains("E1 Squash 8"), card)
        XCTAssertFalse(card.contains("?"), card)
        // A name filled in replaces its default; the other side keeps its own
        played.ownPlayer = "Gerd-Jan"
        withGame.update(played)
        XCTAssertTrue(TeamMatchReport.text(withGame, style: MatchShareStyle.report).contains("*E1* Gerd-Jan – Squash Delft 8 E1 · 1-0"))
    }

    func testADefaultNameStoredByAMatchIsEmptiedAgain() {
        let match = team()
        var partij = TeamPartij(slot: 2, ownPlayer: "All Inn Squash 8 E2", opponentPlayer: "Piet")
        partij = match.cleaned(partij)
        XCTAssertEqual(partij.ownPlayer, "")
        XCTAssertEqual(partij.opponentPlayer, "Piet")
        let away = team(ownSide: .away)
        let other = away.cleaned(TeamPartij(slot: 2, ownPlayer: "squash delft 8 e2", opponentPlayer: "All Inn Squash 8 E2"))
        XCTAssertEqual(other.ownPlayer, "")
        XCTAssertEqual(other.opponentPlayer, "")
    }

    // MARK: Uitnodiging

    func testAnInviteIsALinkOrACodeAndNothingElse() {
        let invite = TeamInvite(id: "abcdefghjkmn", key: "K3yK3yK3yK3yK3yK3yK3y_-9")
        XCTAssertEqual(invite.code, "abcdefghjkmn.K3yK3yK3yK3yK3yK3yK3y_-9")
        XCTAssertEqual(invite.link, "https://squashanalyzer.com/team/#abcdefghjkmn.K3yK3yK3yK3yK3yK3yK3y_-9")
        XCTAssertEqual(TeamInvite.parse(invite.code), invite)
        XCTAssertEqual(TeamInvite.parse(invite.link), invite)
        XCTAssertEqual(TeamInvite.parse("squashanalyzer://team#" + invite.code), invite)
        XCTAssertEqual(TeamInvite.parse("Doe mee met onze teamwedstrijd: \(invite.link)\nof plak " + invite.code + " in de app"), invite)
        XCTAssertEqual(TeamInvite.parse("  " + invite.code + "  \n"), invite)
        XCTAssertNil(TeamInvite.parse(""))
        XCTAssertNil(TeamInvite.parse("hallo wereld"))
        XCTAssertNil(TeamInvite.parse("abc.def"))
        XCTAssertNil(TeamInvite.parse("ABCDEFGHJKMN.K3yK3yK3yK3yK3yK3yK3y_-9"), "an id is lower case")
        XCTAssertNil(TeamInvite.parse("abcdefghjkmn.kort"))
        XCTAssertNil(TeamInvite.parse("abcdefghjkmn.K3yK3yK3yK3yK3yK3yK3y!!"))
        XCTAssertEqual(invite.viewerLink(baseURL: "https://live.test"), "https://live.test/t/abcdefghjkmn")
    }

    // MARK: Een partij voor de live-pagina

    func testAHandFilledPartijGoesUpHomeFirstWithOnlyTheScoresItHas() {
        var match = team(ownSide: .away)
        var partij = TeamPartij(slot: 2, ownPlayer: "Jan de Vries", opponentPlayer: "Piet")
        XCTAssertTrue(partij.addGame(TeamGame(own: 11, their: 8)))
        XCTAssertTrue(partij.addGame(TeamGame(ownPoints: nil, theirPoints: nil, ownWon: false)))
        XCTAssertTrue(partij.addGame(TeamGame(own: 11, their: 6)))
        XCTAssertTrue(partij.addGame(TeamGame(own: 9, their: 11)))
        XCTAssertTrue(partij.addGame(TeamGame(own: 11, their: 5)))
        match.update(partij)
        let payload = match.partij(2).livePayload(in: match)!
        // We are away: Piet (home) first, scores turned around
        XCTAssertEqual(payload.p1, "Piet")
        XCTAssertEqual(payload.p2, "Jan")
        XCTAssertEqual(payload.games, [[8, 11], [6, 11], [11, 9], [5, 11]])
        XCTAssertEqual(payload.gamesWon, [2, 3])
        XCTAssertEqual(payload.winner, 2)
        XCTAssertEqual(payload.status, LiveStatus.finished)
        XCTAssertEqual(payload.score, [0, 0])
        XCTAssertNil(match.partij(3).livePayload(in: match), "an empty partij sends nothing")
        // Without names the payload has none: the page shows the default
        var bare = TeamPartij(slot: 1)
        XCTAssertTrue(bare.addGame(TeamGame(own: 11, their: 3)))
        let none = bare.livePayload(in: team())!
        XCTAssertEqual(none.p1, "")
        XCTAssertEqual(none.p2, "")
        XCTAssertEqual(none.status, LiveStatus.between)
        XCTAssertNil(none.winner)
    }

    func testATrackedMatchIsTurnedAroundWhenTheHomePlayerIsPlayerTwo() {
        let live = snapshot("Piet", "Jan", score: [3, 7], games: [[11, 9], [4, 11]], won: [1, 1], server: 2, status: LiveStatus.playing)
        let straight = TeamLivePartij(snapshot: live, homeIsPlayer1: true, homeLabel: "Piet", awayLabel: "")
        XCTAssertEqual(straight.score, [3, 7])
        XCTAssertEqual(straight.games, [[11, 9], [4, 11]])
        XCTAssertEqual(straight.server, 2)
        XCTAssertEqual(straight.p2, "")
        let turned = TeamLivePartij(snapshot: live, homeIsPlayer1: false, homeLabel: "Jan", awayLabel: "Piet")
        XCTAssertEqual(turned.score, [7, 3])
        XCTAssertEqual(turned.games, [[9, 11], [11, 4]])
        XCTAssertEqual(turned.gamesWon, [1, 1])
        XCTAssertEqual(turned.server, 1)
        XCTAssertEqual(turned.p1, "Jan")
        XCTAssertEqual(turned.lastPoint, "Jan: Winner")
        let won = snapshot("A", "B", score: [11, 5], games: [[11, 5]], won: [1, 0], status: LiveStatus.finished, winner: 1)
        XCTAssertEqual(TeamLivePartij(snapshot: won, homeIsPlayer1: false, homeLabel: "", awayLabel: "").winner, 2)
    }

    // MARK: Van de live-pagina

    func testPartijenFromOtherPhonesAreTakenOverUntilWeEditThem() {
        let json = """
        {"team":{"home":"All Inn Squash 8","away":"Squash Delft 8","date":1793181600000},
         "partijen":{"1":{"p1":"Piet","p2":"Jan","bestOf":5,"games":[[11,9],[4,11]],"score":[3,5],"gamesWon":[1,1],"server":1,"side":"R","status":"playing"},
                     "3":{"p1":"","p2":"","bestOf":5,"games":[],"score":[0,0],"gamesWon":[1,3],"server":1,"side":"R","status":"finished","winner":2}},
         "updatedAt":1793181700000}
        """
        let state = try! JSONDecoder().decode(TeamLiveState.self, from: json.data(using: String.Encoding.utf8)!)
        XCTAssertEqual(state.team.home, "All Inn Squash 8")
        XCTAssertEqual(state.partijen.count, 2)
        XCTAssertEqual(state.partijen["1"]?.games, [[11, 9], [4, 11]])

        let invite = TeamInvite(id: "abcdefghjkmn", key: "K3yK3yK3yK3yK3yK3yK3y_-9")
        var match = TeamMatch.joining(state, invite: invite, ownSide: .away)
        XCTAssertEqual(match.home, "All Inn Squash 8")
        XCTAssertEqual(match.liveId, "abcdefghjkmn")
        XCTAssertEqual(match.liveKey, invite.key)
        XCTAssertTrue(match.isLive)
        XCTAssertEqual(match.date, Date(timeIntervalSince1970: 1_793_181_600.0))
        // We are away: Jan (away) is ours, scores turned
        let first = match.partij(1)
        XCTAssertEqual(first.ownPlayer, "Jan")
        XCTAssertEqual(first.opponentPlayer, "Piet")
        XCTAssertEqual(first.gamesText, "9-11, 11-4")
        XCTAssertEqual(first.fromLive, true)
        XCTAssertEqual(first.standText, "1-1")
        // Only who won, no scores: the games are there without a score
        let third = match.partij(3)
        XCTAssertEqual(third.games.count, 4)
        XCTAssertEqual(third.ownGames, 3)
        XCTAssertEqual(third.theirGames, 1)
        XCTAssertEqual(third.gamesText, "–, –, –, –")
        XCTAssertTrue(third.isOver)
        XCTAssertFalse(match.partij(2).hasEntry)

        // The page moves on: partij 1 follows it, as long as nobody edited it here
        var moved = state
        moved.partijen["1"] = TeamLivePartij(p1: "Piet", p2: "Jan", bestOf: 5, games: [[11, 9], [4, 11], [11, 7]], score: [0, 0],
                                             gamesWon: [2, 1], server: 1, side: "R", status: LiveStatus.between)
        XCTAssertTrue(match.mergeLive(moved))
        XCTAssertEqual(match.partij(1).games.count, 3)
        XCTAssertFalse(match.mergeLive(moved), "nothing new the second time")
        // We edit it: from now on it is ours and the page no longer overwrites it
        var edited = match.partij(1)
        edited.removeLastGame()
        match.update(edited)
        XCTAssertNil(match.partij(1).fromLive)
        XCTAssertFalse(match.mergeLive(moved))
        XCTAssertEqual(match.partij(1).games.count, 2)
        // Our own partij is never taken over, and an empty page slot changes nothing
        var own = TeamPartij(slot: 2, ownPlayer: "Eigen", opponentPlayer: "Tegen")
        XCTAssertTrue(own.addGame(TeamGame(own: 11, their: 1)))
        match.update(own)
        moved.partijen["2"] = TeamLivePartij(p1: "X", p2: "Y", bestOf: 5, games: [[1, 11]], score: [0, 0], gamesWon: [0, 1],
                                             server: 1, side: "R", status: LiveStatus.between)
        XCTAssertFalse(match.mergeLive(moved))
        XCTAssertEqual(match.partij(2).ownPlayer, "Eigen")
    }

    // MARK: De service

    @MainActor
    func testTheTeamMatchGoesLiveAndItsPartijenAreSent() async throws {
        let transport = FakeTeamTransport()
        let live = TeamLive(transport: transport)
        live.baseURL = "https://live.test"
        var match = team()
        let created = try await live.create(match)
        XCTAssertEqual(created.id, "abcdefghjkmn")
        XCTAssertEqual(created.url, "https://live.test/t/abcdefghjkmn")
        XCTAssertEqual(transport.requests[0].method, "POST")
        XCTAssertEqual(transport.requests[0].url, "https://live.test/api/team")
        XCTAssertTrue(transport.requests[0].body.contains("\"home\":\"All Inn Squash 8\""), transport.requests[0].body)
        XCTAssertTrue(transport.requests[0].body.contains("\"date\":1793181600000"), transport.requests[0].body)

        match.liveId = created.id
        match.liveKey = created.writeKey
        var partij = TeamPartij(slot: 3, ownPlayer: "Gerd-Jan van Gils", opponentPlayer: "Ronald")
        XCTAssertTrue(partij.addGame(TeamGame(own: 11, their: 4)))
        match.update(partij)
        var other = TeamPartij(slot: 1)
        XCTAssertTrue(other.addGame(TeamGame(own: 11, their: 2)))
        match.update(other)
        // A partij that came from the page is not sent back
        var echoed = TeamPartij(slot: 4, ownPlayer: "X", opponentPlayer: "Y", games: [TeamGame(own: 11, their: 0)])
        echoed.fromLive = true
        match.partijen[3] = echoed

        await live.pushAll(match)
        let puts = transport.requests.filter { request in request.method == "PUT" }
        XCTAssertEqual(puts.map { request in request.url }, ["https://live.test/api/team/abcdefghjkmn/partij/1",
                                                            "https://live.test/api/team/abcdefghjkmn/partij/3"])
        XCTAssertEqual(puts[1].key, "Bearer K3yK3yK3yK3yK3yK3yK3yK3y")
        XCTAssertTrue(puts[1].body.contains("\"p1\":\"Gerd-Jan\""), puts[1].body)
        XCTAssertTrue(puts[1].body.contains("\"gamesWon\":[1,0]"), puts[1].body)

        // Not live: nothing is sent
        let before = transport.requests.count
        let quiet = await live.push(partij, in: team())
        XCTAssertFalse(quiet)
        XCTAssertEqual(transport.requests.count, before)

        await live.stop(match)
        XCTAssertEqual(transport.requests.last?.method, "DELETE")
        XCTAssertEqual(transport.requests.last?.url, "https://live.test/api/team/abcdefghjkmn")
    }

    @MainActor
    func testATrackedMatchForwardsEveryChangeToItsPartij() async throws {
        let transport = FakeTeamTransport()
        let live = TeamLive(transport: transport)
        live.baseURL = "https://live.test"
        let matchId = UUID()
        live.forward(matchId: matchId, snapshot: snapshot("Jan", "Piet", score: [1, 0]))
        XCTAssertTrue(transport.requests.isEmpty, "not bound: nothing goes")

        live.bind(matchId: matchId, teamId: "abcdefghjkmn", writeKey: "K3yK3yK3yK3yK3yK3yK3yK3y", slot: 2,
                  homeIsPlayer1: true, homeLabel: "Jan", awayLabel: "")
        XCTAssertTrue(live.isBound(matchId))
        live.forward(matchId: matchId, snapshot: snapshot("Jan", "Piet", score: [1, 0]))
        live.forward(matchId: matchId, snapshot: snapshot("Jan", "Piet", score: [2, 0]))
        live.forward(matchId: matchId, snapshot: snapshot("Jan", "Piet", score: [3, 0]))
        // Three changes in a row are merged: only the newest state goes
        try await waitUntil { transport.requests.count >= 1 && transport.requests[transport.requests.count - 1].body.contains("\"score\":[3,0]") }
        XCTAssertEqual(transport.requests.count, 1)
        let last = transport.requests[transport.requests.count - 1]
        XCTAssertEqual(last.method, "PUT")
        XCTAssertEqual(last.url, "https://live.test/api/team/abcdefghjkmn/partij/2")
        XCTAssertTrue(last.body.contains("\"p2\":\"\""), last.body)
        XCTAssertTrue(last.body.contains("\"lastPoint\":\"Jan: Winner\""), last.body)

        // No network: the newest state is kept and goes with the next change
        transport.offline = true
        live.forward(matchId: matchId, snapshot: snapshot("Jan", "Piet", score: [4, 0]))
        try await waitUntil { live.offline }
        transport.offline = false
        let sent = transport.requests.count
        live.forward(matchId: matchId, snapshot: snapshot("Jan", "Piet", score: [5, 0]))
        try await waitUntil { transport.requests.count > sent && transport.requests[transport.requests.count - 1].body.contains("\"score\":[5,0]") }
        XCTAssertFalse(live.offline)

        live.unbind(matchId: matchId)
        XCTAssertFalse(live.isBound(matchId))
    }

    @MainActor
    func testReadingThePageAndAPageThatIsGone() async throws {
        let transport = FakeTeamTransport()
        let live = TeamLive(transport: transport)
        live.baseURL = "https://live.test"
        transport.getBody = "{\"team\":{\"home\":\"A\",\"away\":\"B\",\"date\":1793181600000},\"partijen\":{},\"updatedAt\":1}"
        let state = try await live.fetch(id: "abcdefghjkmn")
        XCTAssertEqual(state.team.away, "B")
        XCTAssertEqual(transport.requests[0].url, "https://live.test/api/team/abcdefghjkmn")
        transport.getStatus = 404
        do {
            _ = try await live.fetch(id: "abcdefghjkmn")
            XCTFail("a page that is gone must throw")
        } catch let error as TeamLiveError {
            XCTAssertEqual(error, TeamLiveError.gone)
        }
        transport.offline = true
        do {
            _ = try await live.fetch(id: "abcdefghjkmn")
            XCTFail("no network must throw")
        } catch let error as TeamLiveError {
            XCTAssertEqual(error, TeamLiveError.noConnection)
        }
    }

    func testTheLiveKeyStaysOutOfTheBackup() {
        var match = team()
        match.liveId = "abcdefghjkmn"
        match.liveKey = "K3yK3yK3yK3yK3yK3yK3yK3y"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("teamlive-\(UUID().uuidString)")
        try? TeamMatchFile.write([match], in: folder)
        let plain = FullBackup(version: 2, backupDate: day, players: [], matches: [], standaloneGames: [])
        let attached = TeamBackup.attach(plain, directory: folder)
        XCTAssertEqual(attached.teamMatches?.count, 1)
        XCTAssertNil(attached.teamMatches?[0].liveKey)
        XCTAssertNil(attached.teamMatches?[0].liveId)
        XCTAssertEqual(TeamMatchFile.read(in: folder)[0].liveKey, "K3yK3yK3yK3yK3yK3yK3yK3y", "the file on the phone keeps it")
        try? FileManager.default.removeItem(at: folder)
    }
}
