import XCTest
import Foundation
@testable import SquashAnalyzerCore

// 4.0 without a player code: players in Spelers linked to SBN players, the
// recipient of a finished match, claiming a team match and learning links.
final class AccountLinkingTests: XCTestCase {
    private let team = "https://sbn.toernooi.nl/league/0a1b2c3d-0000-4000-8000-000000000000/team/113"
    private let teamKey = "0A1B2C3D-0000-4000-8000-000000000000/113"

    private func defaults() -> UserDefaults {
        // A fresh suite each time: nothing left from another test
        UserDefaults(suiteName: "acct-linking-\(UUID().uuidString)")!
    }

    private func endpoints() -> AccountEndpoints {
        AccountEndpoints(accountURL: "https://account.test", identityURL: "https://id.test/v1",
                         tokenURL: "https://token.test/v1", apiKey: "k")
    }

    private func coachMatch() -> Match {
        let match = Match()
        match.player1Name = "Gerd Lasso"
        match.player2Name = "Mark"
        let game = match.currentGame
        game.start()
        for _ in 0..<11 {
            game.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        }
        return match
    }

    func testTheTeamLinkAsTheServerKnowsIt() throws {
        XCTAssertEqual(try LeagueTeamLink(team).accountKey, teamKey)
        let store = defaults()
        XCTAssertNil(AccountSending.ownTeamKey(in: store))
        store.set(team, forKey: LeagueTeamStorage.linkKey)
        XCTAssertEqual(AccountSending.ownTeamKey(in: store), teamKey)
    }

    func testNameKeyMatchesTheWorker() {
        XCTAssertEqual(AccountSending.nameKey("  Gerd   LASSO "), "gerd lasso")
    }

    func testLinksAreOnePlayerPerSbnPlayer() {
        let store = defaults()
        PlayerSBNLinks.set("/league/x/player/1", for: "a", in: store)
        PlayerSBNLinks.set("/league/x/player/1", for: "b", in: store)
        XCTAssertNil(PlayerSBNLinks.path(for: "a", in: store))
        XCTAssertEqual(PlayerSBNLinks.path(for: "b", in: store), "/league/x/player/1")
        PlayerSBNLinks.set(nil, for: "b", in: store)
        XCTAssertTrue(PlayerSBNLinks.all(in: store).isEmpty)
    }

    func testTeamPlayersWithTheSameNameGetLinked() {
        let store = defaults()
        let sbn = [LeaguePlayer(id: "/league/x/player/1", name: "Gerd-Jan van Gils", record: ""),
                   LeaguePlayer(id: "/league/x/player/2", name: "Mark de Vries", record: "")]
        let players = [PlayerProfile(id: "a", name: "gerd-jan van gils"), PlayerProfile(id: "b", name: "Gerd Lasso")]
        XCTAssertEqual(PlayerSBNLinks.fill(from: sbn, players: players, in: store), 1)
        XCTAssertEqual(PlayerSBNLinks.path(for: "a", in: store), "/league/x/player/1")
        XCTAssertNil(PlayerSBNLinks.path(for: "b", in: store), "another name: chosen by hand or claimed")
        XCTAssertEqual(PlayerSBNLinks.fill(from: sbn, players: players, in: store), 0, "already linked")
    }

    func testRecipientIsTheSbnPlayerOrTheNameInTheTeam() {
        let store = defaults()
        XCTAssertNil(AccountSending.recipient(playerId: "b", name: "Gerd Lasso", in: store), "not in the team, no link")
        TeamRoster.replace(["b"], in: store)
        XCTAssertNil(AccountSending.recipient(playerId: "b", name: "Gerd Lasso", in: store), "no Mijn team link")
        store.set(team, forKey: LeagueTeamStorage.linkKey)
        XCTAssertEqual(AccountSending.recipient(playerId: "b", name: " Gerd Lasso ", in: store),
                       AccountRecipient(team: teamKey, name: "Gerd Lasso"))
        PlayerSBNLinks.set("/league/x/player/1", for: "b", in: store)
        XCTAssertEqual(AccountSending.recipient(playerId: "b", name: "Gerd Lasso", in: store),
                       AccountRecipient(sbnPath: "/league/x/player/1"))
        XCTAssertNil(AccountSending.recipient(playerId: nil, name: "Gerd Lasso", in: store))
    }

    @MainActor
    func testAFinishedMatchIsQueuedForBothPlayersAndTheOwnSideCountsAtOnce() {
        let store = defaults()
        store.set(team, forKey: LeagueTeamStorage.linkKey)
        TeamRoster.replace(["b"], in: store)
        PlayerSBNLinks.set("/league/x/player/9", for: "m", in: store)
        let box = AccountOutbox()
        box.configure(directory: FileManager.default.temporaryDirectory.appendingPathComponent("acct-link-\(UUID().uuidString)"))
        let match = coachMatch()
        let queued = AccountSending.queue(upload: { side in match.accountUpload(for: side) },
                                          playerIds: [Player.player1: "b", Player.player2: "m"],
                                          playerNames: [Player.player1: "Gerd Lasso", Player.player2: "Mark"],
                                          senderName: "Peter", ownSbnPath: "/league/x/player/9", outbox: box, in: store)
        XCTAssertEqual(queued, 2)
        XCTAssertEqual(box.entries.first { entry in entry.recipient?.team != nil }?.recipient?.name, "Gerd Lasso")
        XCTAssertEqual(box.entries.filter { entry in entry.isOwn }.count, 1, "Mark is the signed-in player")
        // Saving the finished match again keeps one copy each
        AccountSending.queue(upload: { side in match.accountUpload(for: side) },
                             playerIds: [Player.player1: "b", Player.player2: "m"],
                             playerNames: [Player.player1: "Gerd Lasso", Player.player2: "Mark"],
                             senderName: "Peter", ownSbnPath: "/league/x/player/9", outbox: box, in: store)
        XCTAssertEqual(box.entries.count, 2)
        // An oefenpartij never goes
        let practice = coachMatch()
        PracticeMatches.shared.set(true, for: practice.id)
        defer { PracticeMatches.shared.set(false, for: practice.id) }
        XCTAssertEqual(AccountSending.queue(upload: { side in practice.accountUpload(for: side) },
                                            playerIds: [Player.player1: "b"], playerNames: [Player.player1: "Gerd Lasso"],
                                            senderName: "Peter", ownSbnPath: nil, outbox: box, in: store), 0)
    }

    func testLearnedLinksLinkThePlayerOfThisTeamOnly() {
        let store = defaults()
        let players = [PlayerProfile(id: "b", name: "Gerd  Lasso"), PlayerProfile(id: "c", name: "Kees")]
        let learned = [AccountLearnedLink(teamKey: teamKey, name: "gerd lasso", sbnPath: "/league/x/player/1"),
                       AccountLearnedLink(teamKey: "OTHER/1", name: "kees", sbnPath: "/league/x/player/2")]
        XCTAssertEqual(PlayerSBNLinks.learn(learned, players: players, teamKey: nil, in: store), 0)
        XCTAssertEqual(PlayerSBNLinks.learn(learned, players: players, teamKey: teamKey, in: store), 1)
        XCTAssertEqual(PlayerSBNLinks.path(for: "b", in: store), "/league/x/player/1")
        XCTAssertNil(PlayerSBNLinks.path(for: "c", in: store))
    }

    @MainActor
    func testClaimingATeamMatchAndCorrectingTheName() async throws {
        let transport = FakeAccountTransport()
        let account = PlayerAccount()
        account.configure(endpoints: endpoints(), transport: transport, secrets: MemoryAccountSecrets())
        try await account.signIn(email: "a@b.nl", password: "geheim1")
        try await account.createAccount(name: "Peter", birthYear: 1990, sbnPath: nil, consent: true)
        transport.teamPending = [("M-1", "Gerd Lasso"), ("M-2", "Kees")]
        try await account.loadInbox()
        XCTAssertEqual(account.teamInbox.map { match in match.name ?? "" }, ["Gerd Lasso", "Kees"])
        try await account.claimTeamMatch(account.teamInbox[0])
        XCTAssertEqual(transport.claimed, ["M-1"])
        XCTAssertTrue(transport.requests.contains { request in
            request.url.hasSuffix("/api/v1/me/team/M-1")
                && String(data: request.body ?? Data(), encoding: String.Encoding.utf8) == "{\"name\":\"Gerd Lasso\"}"
        })
        XCTAssertEqual(account.teamInbox.count, 1)
        account.hideTeamMatch(account.teamInbox[0])
        XCTAssertTrue(account.teamInbox.isEmpty)

        do {
            try await account.updateAccount(name: "  ")
            XCTFail("an empty name is refused before asking")
        } catch let error as AccountError {
            XCTAssertEqual(error, AccountError.missingName)
        }
        try await account.updateAccount(name: " Gerd-Jan ")
        XCTAssertEqual(account.profile?.name, "Gerd-Jan")
        XCTAssertTrue(transport.patches.last?.contains("\"name\":\"Gerd-Jan\"") == true)
    }

    @MainActor
    func testAShareLinkAndLearningLinks() async throws {
        let transport = FakeAccountTransport()
        let account = PlayerAccount()
        account.configure(endpoints: endpoints(), transport: transport, secrets: MemoryAccountSecrets())
        let nothing = await account.learnLinks(players: [])
        XCTAssertEqual(nothing, 0, "no device key yet: nothing sent, nothing to learn")
        let upload = try XCTUnwrap(coachMatch().accountUpload(for: Player.player1))
        let token = try await account.shareLink(upload, senderName: "Peter")
        XCTAssertEqual(token, "tok123")
        try await account.signIn(email: "a@b.nl", password: "geheim1")
        try await account.createAccount(name: "Peter", birthYear: 1990, sbnPath: nil, consent: true)
        let claimed = try await account.claimLink(token)
        XCTAssertEqual(claimed.status, "accepted")
        XCTAssertNotNil(claimed.badgeInput)
    }

    func testClaimLinksInAndOut() {
        XCTAssertEqual(AccountClaimLink.url(token: "abcDEF123456"), "https://squashanalyzer.com/wedstrijd#abcDEF123456")
        XCTAssertEqual(AccountClaimLink.token(from: "https://squashanalyzer.com/wedstrijd#abcDEF123456"), "abcDEF123456")
        XCTAssertEqual(AccountClaimLink.token(from: "https://www.squashanalyzer.com/wedstrijd/#abcDEF123456"), "abcDEF123456")
        XCTAssertEqual(AccountClaimLink.token(from: "squashanalyzer://wedstrijd#abcDEF123456"), "abcDEF123456")
        XCTAssertNil(AccountClaimLink.token(from: "https://squashanalyzer.com/kaart#abcDEF123456"))
        XCTAssertNil(AccountClaimLink.token(from: "https://squashanalyzer.com/wedstrijd#short"))
        XCTAssertNil(AccountClaimLink.token(from: "https://squashanalyzer.com/wedstrijd#abc/../DEF123456"))
    }

    @MainActor
    func testASessionTheWorkerRefusesSignsOut() async throws {
        let transport = FakeAccountTransport()
        let account = PlayerAccount()
        account.configure(endpoints: endpoints(), transport: transport, secrets: MemoryAccountSecrets())
        try await account.signIn(email: "a@b.nl", password: "geheim1")
        transport.meStatus = 401
        do {
            try await account.loadProfile()
            XCTFail("a refused session throws")
        } catch let error as AccountError {
            XCTAssertEqual(error, AccountError.signInAgain)
        }
        XCTAssertFalse(account.isSignedIn, "the screen shows signing in again")
    }
}
