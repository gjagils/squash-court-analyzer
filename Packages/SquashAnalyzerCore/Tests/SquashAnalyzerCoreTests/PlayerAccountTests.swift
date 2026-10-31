import XCTest
import Foundation
@testable import SquashAnalyzerCore

// 4.0, the player account: Firebase sign-in over REST, the account Worker's
// client, the compact match and the outgoing queue. A fake transport stands in
// for Firebase and the Worker.
final class PlayerAccountTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }

    private func endpoints() -> AccountEndpoints {
        AccountEndpoints(accountURL: "https://account.test", identityURL: "https://id.test/v1",
                         tokenURL: "https://token.test/v1", apiKey: "k")
    }

    private func body(_ request: FakeAccountRequest) -> String {
        String(data: request.body ?? Data(), encoding: String.Encoding.utf8) ?? ""
    }

    // MARK: - Endpoints

    func testEndpointsFromTheBuildSettings() {
        XCTAssertEqual(AccountEndpoints.from(server: "local", apiKey: nil, defaultHost: "10.0.2.2").accountURL, "http://10.0.2.2:8787")
        XCTAssertEqual(AccountEndpoints.from(server: "local:192.168.1.5", apiKey: nil, defaultHost: "localhost").identityURL,
                       "http://192.168.1.5:9099/identitytoolkit.googleapis.com/v1")
        let production = AccountEndpoints.from(server: "", apiKey: "abc", defaultHost: "localhost")
        XCTAssertEqual(production.accountURL, AccountEndpoints.productionAccountURL)
        XCTAssertEqual(production.tokenURL, "https://securetoken.googleapis.com/v1")
        XCTAssertEqual(production.apiKey, "abc")
    }

    // MARK: - Firebase

    func testFirebaseErrorsInWords() {
        XCTAssertEqual(AccountError.firebase("EMAIL_EXISTS", status: 400), AccountError.emailExists)
        XCTAssertEqual(AccountError.firebase("WEAK_PASSWORD : Password should be at least 6 characters", status: 400), AccountError.weakPassword)
        XCTAssertEqual(AccountError.firebase("INVALID_LOGIN_CREDENTIALS", status: 400), AccountError.wrongCredentials)
        XCTAssertEqual(AccountError.firebase("TOKEN_EXPIRED", status: 400), AccountError.signInAgain)
        XCTAssertEqual(AccountError.firebase("SOMETHING_NEW", status: 400), AccountError.server(status: 400))
        XCTAssertTrue(AccountError.tooYoung.message.contains("16"))
    }

    func testSignUpGoesToFirebaseWithTheKey() async throws {
        let transport = FakeAccountTransport()
        let auth = FirebaseAuthREST(endpoints: endpoints(), transport: transport)
        let now = Date(timeIntervalSince1970: 1_000.0)
        let session = try await auth.signUp(email: "a@b.nl", password: "geheim1", now: now)
        XCTAssertEqual(transport.requests.first?.url, "https://id.test/v1/accounts:signUp?key=k")
        XCTAssertTrue(body(transport.requests[0]).contains("\"returnSecureToken\":true"))
        XCTAssertEqual(session.uid, "uid-1")
        XCTAssertEqual(session.email, "a@b.nl")
        XCTAssertEqual(session.expiresAt, Int64(1_000_000 + 3_600_000))
        XCTAssertTrue(session.isFresh(at: now))
        XCTAssertFalse(session.isFresh(at: Date(timeIntervalSince1970: 1_000.0 + 3_400.0)), "five minutes before expiry it is refreshed")
    }

    func testAFirebaseRefusalComesBackAsAnError() async {
        let transport = FakeAccountTransport()
        transport.firebaseError = "EMAIL_EXISTS"
        let auth = FirebaseAuthREST(endpoints: endpoints(), transport: transport)
        do {
            _ = try await auth.signUp(email: "a@b.nl", password: "geheim1")
            XCTFail("should refuse")
        } catch {
            XCTAssertEqual(error as? AccountError, AccountError.emailExists)
        }
    }

    func testNoApiKeyIsNotConfigured() async {
        var noKey = endpoints()
        noKey.apiKey = ""
        let auth = FirebaseAuthREST(endpoints: noKey, transport: FakeAccountTransport())
        do {
            _ = try await auth.signIn(email: "a@b.nl", password: "x")
            XCTFail("should refuse")
        } catch {
            XCTAssertEqual(error as? AccountError, AccountError.notConfigured)
        }
    }

    func testRefreshUsesSecuretokenNames() async throws {
        let transport = FakeAccountTransport()
        let auth = FirebaseAuthREST(endpoints: endpoints(), transport: transport)
        let old = AuthSession(uid: "uid-1", email: "a@b.nl", idToken: "old", refreshToken: "r1", expiresAt: 0, provider: "password")
        let fresh = try await auth.refresh(old)
        XCTAssertEqual(transport.requests.first?.url, "https://token.test/v1/token?key=k")
        XCTAssertTrue(body(transport.requests[0]).contains("\"grant_type\":\"refresh_token\""))
        XCTAssertTrue(body(transport.requests[0]).contains("\"refresh_token\":\"r1\""))
        XCTAssertEqual(fresh.idToken, "id-2")
        XCTAssertEqual(fresh.refreshToken, "r2")
        XCTAssertEqual(fresh.email, "a@b.nl")
    }

    func testAppleTokenIsRevokedThroughTheV2Api() async throws {
        let transport = FakeAccountTransport()
        let auth = FirebaseAuthREST(endpoints: endpoints(), transport: transport)
        try await auth.revokeAppleToken(idToken: "id", authorizationCode: "code")
        XCTAssertEqual(transport.requests.first?.url, "https://id.test/v2/accounts:revokeToken?key=k")
        XCTAssertTrue(body(transport.requests[0]).contains("\"tokenType\":\"CODE\""))
    }

    // MARK: - Worker client

    func testClientSendsTheTokenAndReadsNoAccount() async throws {
        let transport = FakeAccountTransport()
        let client = AccountClient(baseURL: "https://account.test", transport: transport)
        let none = try await client.me(token: "tok")
        XCTAssertNil(none)
        XCTAssertEqual(transport.requests.first?.headers["Authorization"], "Bearer tok")
        let made = try await client.createAccount(token: "tok", AccountCreation(name: "Peter", birthYear: 1990, sbnPath: nil, consent: true))
        XCTAssertEqual(made.code, "ABCDEFGHJK")
        let again = try await client.me(token: "tok")
        XCTAssertEqual(again?.name, "Peter")
    }

    func testWorkerRefusalsInWords() {
        XCTAssertEqual(AccountClient.error(status: 403, text: "too young"), AccountError.tooYoung)
        XCTAssertEqual(AccountClient.error(status: 409, text: "sbnPath taken"), AccountError.sbnPathTaken)
        XCTAssertEqual(AccountClient.error(status: 401, text: "sign in"), AccountError.signInAgain)
        XCTAssertEqual(AccountClient.error(status: 400, text: "consent"), AccountError.missingConsent)
        XCTAssertEqual(AccountClient.error(status: 429, text: ""), AccountError.tooManyRequests)
        XCTAssertEqual(AccountClient.error(status: 500, text: "server"), AccountError.server(status: 500))
    }

    func testSubmissionCarriesTheDeviceKeyAndTheMatchAtTheTop() async throws {
        let transport = FakeAccountTransport()
        let client = AccountClient(baseURL: "https://account.test", transport: transport)
        let device = try await client.createDevice()
        let upload = try XCTUnwrap(coachMatch().accountUpload(for: Player.player1))
        try await client.submit(device: device, AccountSubmission(match: upload, to: AccountRecipient(code: "ABCDEFGHJK"), senderName: "Coach Jan"))
        let request = try XCTUnwrap(transport.requests.last)
        XCTAssertEqual(request.headers["Authorization"], "Device dev-1.key-1")
        let text = body(request)
        XCTAssertTrue(text.contains("\"matchId\":\"\(upload.matchId)\""))
        XCTAssertTrue(text.contains("\"code\":\"ABCDEFGHJK\""))
        XCTAssertTrue(text.contains("\"senderName\":\"Coach Jan\""))
    }

    // MARK: - Compact match

    private func coachMatch() -> Match {
        let match = Match()
        match.player1Name = "Peter"
        match.player2Name = "Mark"
        let game = match.currentGame
        game.start()
        game.addPoint(to: Player.player2, pointType: PointType.winner, at: CourtZone.frontLeft, with: ShotType.drop, isVolley: true)
        for _ in 0..<11 {
            game.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        }
        return match
    }

    func testCompactMatchKeepsWhatBadgesNeed() throws {
        let match = coachMatch()
        let original = match.badgeInput
        let upload = try XCTUnwrap(match.accountUpload(for: Player.player1))
        XCTAssertEqual(upload.matchId, match.id.uuidString.uppercased())
        XCTAssertEqual(upload.summary.kind, "coach")
        XCTAssertEqual(upload.opponent, "Mark")
        XCTAssertEqual(upload.summary.scores, [[11, 1]])
        XCTAssertEqual(upload.summary.resultLine, "1-0 tegen Mark")

        // Through JSON and back, as from the server
        let data = try JSONEncoder().encode(upload)
        let back = try JSONDecoder().decode(AccountMatchUpload.self, from: data)
        let input = back.badgeInput
        XCTAssertEqual(input.games.count, original.games.count)
        XCTAssertEqual(input.games[0].winner, original.games[0].winner)
        XCTAssertEqual(input.games[0].rallies.count, 12)
        let first = input.games[0].rallies[0]
        XCTAssertEqual(first.winner, Player.player2)
        XCTAssertEqual(first.shot, ShotType.drop)
        XCTAssertEqual(first.pointType, PointType.winner)
        XCTAssertEqual(first.zone, CourtZone.frontLeft)
        XCTAssertTrue(first.isVolley)
        XCTAssertEqual(first.server, original.games[0].rallies[0].server)
        XCTAssertEqual(input.matchWinner, original.matchWinner)
        XCTAssertEqual(input.player1GamesWon, original.player1GamesWon)
        XCTAssertEqual(input.gamesToWin, original.gamesToWin)
        XCTAssertEqual(input.recordsPointTypes, original.recordsPointTypes)
        XCTAssertFalse(input.isPractice)
        // The same badges either way
        XCTAssertEqual(BadgeEngine().badges(for: input), BadgeEngine().badges(for: original))
    }

    func testTheOtherSideGetsItsOwnView() throws {
        let upload = try XCTUnwrap(coachMatch().accountUpload(for: Player.player1))
        let mark = upload.forSide(Player.player2)
        XCTAssertEqual(mark.matchId, upload.matchId, "one match id for both players")
        XCTAssertEqual(mark.opponent, "Peter")
        XCTAssertEqual(mark.summary.mySide, Player.player2)
        XCTAssertEqual(mark.summary.result, "0-1")
    }

    func testRefereeMatchInCompactForm() throws {
        let match = RefereeMatch(player1Name: "Jan", player2Name: "Piet", bestOf: 5, startingServer: Player.player1)
        let upload = try XCTUnwrap(match.accountUpload(for: Player.player2))
        XCTAssertEqual(upload.summary.kind, "referee")
        XCTAssertEqual(upload.summary.gamesToWin, 3)
        XCTAssertEqual(upload.opponent, "Jan")
    }

    func testAFullMatchStaysSmall() throws {
        let match = Match()
        match.player1Name = "Peter"
        match.player2Name = "Mark"
        for _ in 0..<4 {
            let game = match.currentGame
            game.start()
            for index in 0..<24 {
                let winner = index % 3 == 0 ? Player.player2 : Player.player1
                if game.isGameOver { break }
                game.addPoint(to: winner, pointType: PointType.forcedError, at: CourtZone.middleRight, with: ShotType.cross)
            }
            if !match.isMatchOver { match.startNewGame() }
        }
        let upload = try XCTUnwrap(match.accountUpload(for: Player.player1))
        let summary = try JSONEncoder().encode(upload.summary)
        let rallies = try JSONEncoder().encode(upload.rallies)
        XCTAssertLessThan(summary.count, 4 * 1024, "the Worker's limit for the summary")
        XCTAssertLessThan(rallies.count, 8 * 1024, "far below the Worker's 32 KB")
    }

    func testAnOefenpartijNeverLeavesThePhone() throws {
        let match = coachMatch()
        PracticeMatches.shared.set(true, for: match.id)
        defer { PracticeMatches.shared.set(false, for: match.id) }
        XCTAssertNil(match.accountUpload(for: Player.player1))
    }

    // MARK: - Outbox

    private func folder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("acct-outbox-\(UUID().uuidString)")
    }

    @MainActor
    private func outbox(in directory: URL? = nil) -> AccountOutbox {
        let box = AccountOutbox()
        box.configure(directory: directory ?? folder())
        return box
    }

    @MainActor
    func testOutboxSurvivesARestartAndKeepsOneCopyPerPlayer() throws {
        let directory = folder()
        let box = outbox(in: directory)
        let upload = try XCTUnwrap(coachMatch().accountUpload(for: Player.player1))
        XCTAssertTrue(box.add(upload, to: AccountRecipient(code: "AAAA"), senderName: "Jan"))
        XCTAssertTrue(box.add(upload, to: AccountRecipient(code: "AAAA"), senderName: "Jan"))
        XCTAssertTrue(box.add(upload.forSide(Player.player2), to: AccountRecipient(code: "BBBB"), senderName: "Jan"))
        XCTAssertEqual(box.entries.count, 2)
        XCTAssertTrue(box.isWaiting(matchId: upload.matchId.lowercased()))

        let reopened = AccountOutbox()
        reopened.configure(directory: directory)
        XCTAssertEqual(reopened.entries, box.entries)
    }

    @MainActor
    func testOutboxRefusesPractice() throws {
        let box = outbox()
        let match = coachMatch()
        let upload = try XCTUnwrap(match.accountUpload(for: Player.player1))
        XCTAssertFalse(box.add(nil, to: AccountRecipient(code: "AAAA"), senderName: "Jan"))
        PracticeMatches.shared.set(true, for: match.id)
        defer { PracticeMatches.shared.set(false, for: match.id) }
        XCTAssertFalse(box.add(upload, to: AccountRecipient(code: "AAAA"), senderName: "Jan"))
        XCTAssertTrue(box.entries.isEmpty)
    }

    @MainActor
    func testOutboxWaitsWithoutNetworkAndSendsOnceBack() async throws {
        let box = outbox()
        let transport = FakeAccountTransport()
        let account = PlayerAccount()
        account.configure(endpoints: endpoints(), transport: transport, secrets: MemoryAccountSecrets(), outbox: box)
        let upload = try XCTUnwrap(coachMatch().accountUpload(for: Player.player1))
        box.add(upload, to: AccountRecipient(code: "AAAA"), senderName: "Jan")

        transport.offline = true
        await account.sendOutbox()
        XCTAssertEqual(box.entries.count, 1, "no signal in the sports hall: it waits")
        XCTAssertEqual(box.entries[0].attempts, 0, "no attempt counted without network")

        transport.offline = false
        await account.sendOutbox()
        XCTAssertTrue(box.entries.isEmpty)
        XCTAssertEqual(transport.submissions, [upload.matchId])

        // A second phone key is never made: it is kept
        box.add(upload, to: AccountRecipient(code: "AAAA"), senderName: "Jan")
        await account.sendOutbox()
        XCTAssertEqual(transport.requests.filter { request in request.url.hasSuffix("/api/v1/devices") }.count, 1)
        XCTAssertEqual(transport.submissions, [upload.matchId, upload.matchId], "the same id: the Worker keeps one")
    }

    @MainActor
    func testOutboxMakesANewDeviceKeyWhenTheOldOneIsUnknown() async throws {
        let box = outbox()
        let transport = FakeAccountTransport()
        let account = PlayerAccount()
        account.configure(endpoints: endpoints(), transport: transport, secrets: MemoryAccountSecrets(), outbox: box)
        box.add(try XCTUnwrap(coachMatch().accountUpload(for: Player.player1)), to: AccountRecipient(code: "AAAA"), senderName: "Jan")
        transport.submitStatus = 401
        await account.sendOutbox()
        XCTAssertEqual(box.entries.count, 1)
        transport.submitStatus = 202
        await account.sendOutbox()
        XCTAssertTrue(box.entries.isEmpty)
        XCTAssertEqual(transport.requests.filter { request in request.url.hasSuffix("/api/v1/devices") }.count, 2)
    }

    @MainActor
    func testOwnMatchesGoOnceSignedIn() async throws {
        let box = outbox()
        let transport = FakeAccountTransport()
        let account = PlayerAccount()
        account.configure(endpoints: endpoints(), transport: transport, secrets: MemoryAccountSecrets(), outbox: box)
        box.add(try XCTUnwrap(coachMatch().accountUpload(for: Player.player1)), to: nil, senderName: "")
        await account.sendOutbox()
        XCTAssertEqual(box.entries.count, 1, "not signed in: it waits")
        try await account.signIn(email: "a@b.nl", password: "geheim1")
        try await account.createAccount(name: "Peter", birthYear: 1990, sbnPath: nil, consent: true)
        await account.sendOutbox()
        XCTAssertTrue(box.entries.isEmpty)
        XCTAssertEqual(transport.ownMatchCalls, 1)
    }

    // MARK: - The account

    @MainActor
    func testSignInKeepsTheSessionAndRefreshesTheToken() async throws {
        let transport = FakeAccountTransport()
        let secrets = MemoryAccountSecrets()
        let account = PlayerAccount()
        account.configure(endpoints: endpoints(), transport: transport, secrets: secrets)
        try await account.register(email: " A@B.nl ", password: "geheim1")
        XCTAssertTrue(account.isSignedIn)
        XCTAssertTrue(account.profileChecked)
        XCTAssertNil(account.profile, "no account made yet")
        XCTAssertTrue(transport.requests.contains { request in request.url.contains("accounts:sendOobCode") }, "verification mail")
        XCTAssertTrue(body(transport.requests[0]).contains("\"email\":\"a@b.nl\""))

        // A restart reads the session back
        let again = PlayerAccount()
        again.configure(endpoints: endpoints(), transport: transport, secrets: secrets)
        XCTAssertEqual(again.session?.uid, "uid-1")
        let later = Date().addingTimeInterval(2.0 * 3600.0)
        let token = try await again.validToken(now: later)
        XCTAssertEqual(token, "id-2")
        XCTAssertTrue(PlayerAccount.read(secrets.accountSecrets).session?.refreshToken == "r2")
    }

    @MainActor
    func testAnExpiredRefreshTokenSignsOut() async throws {
        let transport = FakeAccountTransport()
        let account = PlayerAccount()
        account.configure(endpoints: endpoints(), transport: transport, secrets: MemoryAccountSecrets())
        try await account.signIn(email: "a@b.nl", password: "geheim1")
        transport.firebaseError = "TOKEN_EXPIRED"
        do {
            _ = try await account.validToken(now: Date().addingTimeInterval(7200.0))
            XCTFail("should sign out")
        } catch {
            XCTAssertEqual(error as? AccountError, AccountError.signInAgain)
        }
        XCTAssertFalse(account.isSignedIn)
    }

    @MainActor
    func testUnder16IsRefusedBeforeAsking() async throws {
        let transport = FakeAccountTransport()
        let account = PlayerAccount()
        account.configure(endpoints: endpoints(), transport: transport, secrets: MemoryAccountSecrets())
        try await account.signIn(email: "a@b.nl", password: "geheim1")
        let year = Calendar(identifier: Calendar.Identifier.gregorian).component(Calendar.Component.year, from: Date())
        let calls = transport.requests.count
        do {
            try await account.createAccount(name: "Kind", birthYear: year - 10, sbnPath: nil, consent: true)
            XCTFail("should refuse")
        } catch {
            XCTAssertEqual(error as? AccountError, AccountError.tooYoung)
        }
        XCTAssertEqual(transport.requests.count, calls, "nothing sent")
        XCTAssertEqual(AccountCreation.latestBirthYear(in: 2026), 2010)
    }

    @MainActor
    func testInboxAnswersAndDeleteRevokesApple() async throws {
        let transport = FakeAccountTransport()
        let account = PlayerAccount()
        account.configure(endpoints: endpoints(), transport: transport, secrets: MemoryAccountSecrets())
        try await account.signIn(email: "a@b.nl", password: "geheim1")
        try await account.createAccount(name: "Peter", birthYear: 1990, sbnPath: nil, consent: true)
        let upload = try XCTUnwrap(coachMatch().accountUpload(for: Player.player1))
        transport.pending = [upload.matchId]
        try await account.loadInbox()
        XCTAssertEqual(account.inbox.count, 1)
        XCTAssertEqual(account.inbox[0].senderName, "Coach Jan")
        try await account.answer(matchId: upload.matchId, use: false, block: true)
        XCTAssertTrue(account.inbox.isEmpty)
        XCTAssertTrue(body(transport.requests.last!).contains("\"block\":true"))

        try await account.deleteAccount(appleAuthorizationCode: "code")
        let urls = transport.requests.map { request in request.url }
        let revoke = urls.firstIndex { url in url.contains("accounts:revokeToken") } ?? -1
        let delete = urls.firstIndex { url in url.hasSuffix("/api/v1/me") } ?? -1
        XCTAssertTrue(revoke >= 0)
        XCTAssertTrue(revoke < urls.count - 2, "revoke before the data goes")
        XCTAssertTrue(urls.contains { url in url.contains("accounts:delete") })
        XCTAssertTrue(delete >= 0)
        XCTAssertFalse(account.isSignedIn)
    }
}

struct FakeAccountRequest {
    let method: String
    let url: String
    let headers: [String: String]
    let body: Data?
}

/// Firebase and the account Worker in a few lines
final class FakeAccountTransport: LiveTransport, @unchecked Sendable {
    var requests: [FakeAccountRequest] = []
    var offline = false
    var firebaseError: String? = nil
    var submitStatus = 202
    var submissions: [String] = []
    var ownMatchCalls = 0
    var pending: [String] = []
    private var profile: String? = nil
    private var refreshes = 1

    func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> AITransportResponse {
        if offline { throw URLError(.notConnectedToInternet) }
        let address = url.absoluteString
        requests.append(FakeAccountRequest(method: method, url: address, headers: headers, body: body))
        if address.contains("id.test") || address.contains("token.test") {
            if let firebaseError {
                return reply(400, "{\"error\":{\"code\":400,\"message\":\"\(firebaseError)\"}}")
            }
            if address.contains("/token?") {
                refreshes += 1
                return reply(200, "{\"id_token\":\"id-\(refreshes)\",\"refresh_token\":\"r\(refreshes)\",\"expires_in\":\"3600\",\"user_id\":\"uid-1\"}")
            }
            if address.contains("accounts:signUp") || address.contains("accounts:signInWithPassword") {
                return reply(200, "{\"localId\":\"uid-1\",\"email\":\"a@b.nl\",\"idToken\":\"id-1\",\"refreshToken\":\"r1\",\"expiresIn\":\"3600\"}")
            }
            return reply(200, "{}")
        }
        let path = url.path
        if path == "/api/v1/devices" {
            return reply(201, "{\"deviceId\":\"dev-\(requests.filter { request in request.url.hasSuffix("/devices") }.count)\",\"deviceKey\":\"key-1\"}")
        }
        if path == "/api/v1/submissions" {
            if submitStatus == 202 {
                if let sent = try? JSONDecoder().decode(AccountSubmission.self, from: body ?? Data()) { submissions.append(sent.matchId) }
            }
            return reply(submitStatus, submitStatus == 401 ? "{\"error\":\"device\"}" : "{\"received\":\"x\"}")
        }
        if path == "/api/v1/me" {
            if method == "GET" {
                guard let profile else { return reply(404, "{\"error\":\"no account\"}") }
                return reply(200, profile)
            }
            if method == "POST" {
                profile = "{\"playerId\":\"p-1\",\"name\":\"Peter\",\"code\":\"ABCDEFGHJK\",\"sbnPath\":null,\"birthYear\":1990,\"createdAt\":1}"
                return reply(201, profile ?? "")
            }
            profile = nil
            return reply(204, "")
        }
        if path == "/api/v1/me/matches" && method == "POST" {
            ownMatchCalls += 1
            return reply(200, "{\"stored\":1}")
        }
        if path == "/api/v1/me/inbox" {
            var items: [String] = []
            for id in pending {
                items.append("{\"matchId\":\"\(id)\",\"status\":\"pending\",\"senderName\":\"Coach Jan\",\"fromDevice\":\"dev-1\",\"playedAt\":1,\"receivedAt\":2,\"teamKey\":null,\"opponent\":\"Mark\",\"summary\":{\"v\":1,\"kind\":\"coach\",\"me\":1,\"p1\":\"Peter\",\"p2\":\"Mark\",\"gamesToWin\":3,\"gamesBefore\":[0,0],\"gamesWon\":[1,0],\"winner\":0,\"scores\":[[11,1]],\"duration\":60.5,\"recordsPointTypes\":true}}")
            }
            return reply(200, "{\"matches\":[\(items.joined(separator: ","))]}")
        }
        if path.hasPrefix("/api/v1/me/inbox/") {
            return reply(204, "")
        }
        return reply(404, "{\"error\":\"not found\"}")
    }


    private func reply(_ status: Int, _ text: String) -> AITransportResponse {
        AITransportResponse(status: status, body: text.data(using: String.Encoding.utf8) ?? Data())
    }
}
