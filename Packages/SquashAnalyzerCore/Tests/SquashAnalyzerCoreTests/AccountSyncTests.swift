import XCTest
import Foundation
@testable import SquashAnalyzerCore

// 4.0: the account's matches on the player's phone (AccountSync)
final class AccountSyncTests: XCTestCase {

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "acct-sync-\(UUID().uuidString)")!
    }

    private func endpoints() -> AccountEndpoints {
        AccountEndpoints(accountURL: "https://account.test", identityURL: "https://id.test/v1",
                         tokenURL: "https://token.test/v1", apiKey: "k")
    }

    /// A best-of-1 coach match Peter wins 11-3, as a coach records it
    private func coachMatch() -> Match {
        let match = Match()
        match.player1Name = "Peter"
        match.player2Name = "Mark"
        match.bestOf = 1
        let game = match.currentGame
        // A real clock: 15 seconds a rally (a game of 3.5 minutes earns Sneltrein)
        var clock = Date(timeIntervalSince1970: 1_790_000_000.0)
        game.now = { clock }
        game.start()
        for index in 0..<14 {
            clock = clock.addingTimeInterval(15.0)
            let winner = index % 5 == 4 ? Player.player2 : Player.player1
            game.addPoint(to: winner, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        }
        return match
    }

    private func serverCopy(of match: Match, me: Player, decidedAt: Int64 = 5) throws -> AccountServerMatch {
        let upload = try XCTUnwrap(match.accountUpload(for: me))
        return AccountServerMatch(matchId: upload.matchId, status: "accepted", senderName: "Coach Jan", fromDevice: "dev-1",
                                  playedAt: upload.playedAt, receivedAt: upload.playedAt, teamKey: nil, opponent: upload.opponent,
                                  summary: upload.summary, rallies: upload.rallies, decidedAt: decidedAt)
    }

    func testAnAccountMatchBecomesTheSameMatch() throws {
        let original = coachMatch()
        XCTAssertTrue(original.isMatchOver)
        let own = UUID().uuidString
        let copy = try XCTUnwrap(AccountMatch.match(from: try serverCopy(of: original, me: Player.player2), ownPlayerId: own))
        XCTAssertEqual(copy.id, original.id)
        XCTAssertEqual(copy.player1Name, "Peter")
        XCTAssertEqual(copy.player2Id?.uuidString, own, "the side that is you gets your player")
        XCTAssertNil(copy.player1Id)
        XCTAssertTrue(copy.isMatchOver)
        XCTAssertEqual(copy.matchWinner, original.matchWinner)
        XCTAssertEqual(copy.games[0].player1Score, original.games[0].player1Score)
        XCTAssertEqual(copy.allPoints.count, original.allPoints.count)
        XCTAssertEqual(copy.allPoints.last?.zone, CourtZone.backLeft)
        XCTAssertEqual(copy.allPoints.last?.shotType, ShotType.drive)
        // The same badges as the original
        let engine = BadgeEngine()
        XCTAssertEqual(engine.badges(for: copy.badgeInput), engine.badges(for: original.badgeInput))
    }

    func testNoRalliesOrABadIdGiveNothing() throws {
        var server = try serverCopy(of: coachMatch(), me: Player.player1)
        server = AccountServerMatch(matchId: "not-a-uuid", status: "accepted", senderName: "", fromDevice: nil, playedAt: 1,
                                    receivedAt: 1, teamKey: nil, opponent: "", summary: server.summary, rallies: server.rallies)
        XCTAssertNil(AccountMatch.match(from: server, ownPlayerId: nil))
    }

    @MainActor
    func testSyncImportsOnceForYourPlayerAndNeverSendsItBack() async throws {
        let store = defaults()
        let transport = FakeAccountTransport()
        let account = PlayerAccount()
        account.configure(endpoints: endpoints(), transport: transport, secrets: MemoryAccountSecrets())
        try await account.signIn(email: "a@b.nl", password: "geheim1")
        try await account.createAccount(name: "Peter", birthYear: 1990, sbnPath: nil, consent: true)

        let history = SyncHistoryStore()
        let players = SyncPlayerStore([PlayerProfile(id: "8F1E2C9A-0000-4000-8000-000000000001", name: "peter")])
        let local = coachMatch()
        history.coach.append(local)
        let incoming = UUID().uuidString.uppercased()
        transport.accepted = [(incoming, 10), (local.id.uuidString.uppercased(), 11)]

        let sync = AccountSync()
        sync.configure(history: history, players: players)
        Features.shared.playerAccount = true
        defer { Features.shared.playerAccount = false }
        let first = await sync.run(account: account, in: store)
        XCTAssertEqual(first, 1, "the match recorded on this phone is left alone")
        XCTAssertEqual(history.coach.count, 2)
        let imported = try XCTUnwrap(history.coach.first { match in match.id.uuidString.uppercased() == incoming })
        XCTAssertEqual(imported.player1Id?.uuidString, "8F1E2C9A-0000-4000-8000-000000000001", "you by your account name")
        XCTAssertTrue(AccountImports.contains(imported.id, in: store))
        XCTAssertEqual(AccountImports.since(in: store), 11)

        // Again: nothing new, and a deleted import does not come back
        history.coach.removeAll { match in match.id == imported.id }
        transport.accepted = [(incoming, 10)]
        let second = await sync.run(account: account, in: store)
        XCTAssertEqual(second, 0)
        XCTAssertEqual(history.coach.count, 1)
    }

    @MainActor
    func testWithoutYouInSpelersYouAreAddedAndLinked() async throws {
        let store = defaults()
        let players = SyncPlayerStore([])
        let profile = AccountProfile(playerId: "p", name: "Niels de Groot", code: "X", sbnPath: "/league/x/player/937",
                                     teamKey: nil, birthYear: 1990, createdAt: 1)
        let id = await AccountSync.ownPlayerId(profile, store: players, in: store)
        XCTAssertEqual(players.players.map { player in player.name }, ["Niels de Groot"])
        XCTAssertEqual(PlayerSBNLinks.path(for: try XCTUnwrap(id), in: store), "/league/x/player/937")
        // The next time the linked player is found, not a second one made
        let again = await AccountSync.ownPlayerId(profile, store: players, in: store)
        XCTAssertEqual(again, id)
        XCTAssertEqual(players.players.count, 1)
    }
}

private final class SyncPlayerStore: PlayerProfileStore, @unchecked Sendable {
    var players: [PlayerProfile]
    init(_ players: [PlayerProfile]) { self.players = players }
    func loadPlayers() async throws -> [PlayerProfile] { players }
    func savePlayer(_ player: PlayerProfile) async throws { players.append(player) }
    func deletePlayer(_ id: String) async throws { players = players.filter { other in other.id != id } }
}

@MainActor
private final class SyncHistoryStore: MatchHistoryStore {
    var coach: [Match] = []

    func loadHistory() async throws -> [MatchHistorySummary] { [] }

    func coachMatch(id: String) async throws -> Match? {
        for match in coach where match.id.uuidString == id { return match }
        return nil
    }

    func refereeMatch(id: String) async throws -> RefereeMatch? { nil }

    func saveCoachMatch(_ match: Match) async throws {
        coach = coach.filter { other in other.id != match.id }
        coach.append(match)
    }

    func delete(_ entry: MatchHistorySummary) async throws {}
}
