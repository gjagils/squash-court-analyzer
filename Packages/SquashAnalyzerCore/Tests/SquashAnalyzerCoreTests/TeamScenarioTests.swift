#if !SKIP
import Foundation
import XCTest
@testable import SquashAnalyzerCore

// The team match scenarios on two phones, against the real Workers running on
// the Mac (Gerd-Jan, 21 November 2026: "kun jij de scenario's op twee
// telefoons testen zonder dat ik dat doe"). Each "phone" has its own account,
// its own team match store, its own settings and its own TeamLive; they only
// meet on the account Worker and the live Worker, as two real phones do. So
// what is tested here is the logic of the app and both servers together:
// starting, joining by itself, scoring a partij, closing and resuming,
// throwing a match away, deleting on either phone, joining again, a reinstall.
// Not tested: the screens, and push delivery (APNs and FCM are off locally).
//
// Run with `scripts/team-scenarios.sh` (starts the Workers, runs this, stops
// them). Without TEAM_SCENARIOS=1 the tests are skipped, so the normal
// `swift test` needs no servers.

/// Real HTTP for the scenarios
private struct ScenarioTransport: LiveTransport {
    func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> AITransportResponse {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = method
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        return AITransportResponse(status: (response as? HTTPURLResponse)?.statusCode ?? 0, body: data)
    }
}

/// One phone: an account in the team, its own team matches and settings
@MainActor
private final class ScenarioPhone {
    let name: String
    let context: TeamFindingContext
    let store: JSONFileTeamMatchStore
    let live: TeamLive
    let defaults: UserDefaults
    let teamName: String

    init(name: String, context: TeamFindingContext, liveURL: String, teamName: String) {
        self.name = name
        self.context = context
        self.teamName = teamName
        store = JSONFileTeamMatchStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("scenario-\(UUID().uuidString)"))
        live = TeamLive(transport: ScenarioTransport())
        live.baseURL = liveURL
        defaults = UserDefaults(suiteName: "scenario-\(UUID().uuidString)")!
    }

    func matches() async throws -> [TeamMatch] { try await store.loadAll() }

    /// What the home screen does every minute: look for the team's live team matches and join them
    func lookForTeamMatches() async -> TeamAutoJoin {
        let all = (try? await store.loadAll()) ?? []
        let offers = await TeamFinding.offers(context: context, fixtures: [], matches: all)
        return await TeamFinding.joinOwn(offers, ownTeamName: teamName, fixtures: [], store: store, live: live, defaults: defaults)
    }

    /// What `TeamLiveSync.pull` does for this phone: the page into the stored team matches
    func pull() async throws -> [UUID: TeamLiveSyncResult] {
        var results: [UUID: TeamLiveSyncResult] = [:]
        for match in try await store.loadAll() where match.isLive {
            guard let id = match.liveId else { continue }
            do {
                let state = try await live.fetch(id: id)
                var changed = match
                if changed.mergeLive(state) {
                    try await store.save(changed)
                    results[match.id] = TeamLiveSyncResult.updated
                } else {
                    results[match.id] = TeamLiveSyncResult.unchanged
                }
            } catch let error as TeamLiveError {
                if error == TeamLiveError.gone {
                    results[match.id] = await TeamLiveSync.dropIfEmptyCopy(match, store: store) ? TeamLiveSyncResult.removed : TeamLiveSyncResult.gone
                } else {
                    results[match.id] = TeamLiveSyncResult.failed
                }
            }
        }
        return results
    }

    /// "Verwijder teamwedstrijd", as the team match screen does it
    func delete(_ match: TeamMatch) async throws {
        if match.isLiveOwner { await live.stop(match) }
        if match.isLive { await TeamFinding.forget(match, context: context) }
        if let liveId = match.liveId { TeamFinding.noteJoined(liveId, in: defaults) }
        try await store.delete(id: match.id)
    }
}

@MainActor
final class TeamScenarioTests: XCTestCase {
    private let accountURL = ProcessInfo.processInfo.environment["SCENARIO_ACCOUNT_URL"] ?? "http://localhost:8787"
    private let authURL = ProcessInfo.processInfo.environment["SCENARIO_AUTH_URL"] ?? "http://localhost:9099"
    private let liveURL = ProcessInfo.processInfo.environment["SCENARIO_LIVE_URL"] ?? "http://localhost:8788"
    private let transport = ScenarioTransport()

    /// A league of its own per run, so earlier runs never get in the way
    private let league = UUID().uuidString.uppercased()
    private var teamKey: String { "\(league)/113" }
    private var fixture: String { "/league/\(league)/team-match/1028" }
    private let home = "Scenario Squash 8"
    private let away = "Scenario Woerden 1"

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TEAM_SCENARIOS"] == "1",
                          "needs the local Workers: run scripts/team-scenarios.sh")
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }

    // MARK: Helpers

    private struct SignUp: Decodable { let idToken: String }

    /// A new account in the team, signed in on a new phone
    private func phone(_ name: String, sbnPlayer: Int, existingToken: String? = nil) async throws -> (ScenarioPhone, String) {
        var token = existingToken
        if token == nil {
            let url = URL(string: "\(authURL)/identitytoolkit.googleapis.com/v1/accounts:signUp?key=local-dev")!
            let body = try JSONSerialization.data(withJSONObject: ["email": "\(name.lowercased())-\(UUID().uuidString.prefix(8))@scenario.test",
                                                                   "password": "geheim12", "returnSecureToken": true])
            let response = try await transport.send(method: "POST", url: url, headers: ["Content-Type": "application/json"], body: body)
            XCTAssertEqual(response.status, 200, "sign up \(name)")
            token = try JSONDecoder().decode(SignUp.self, from: response.body).idToken
            let client = AccountClient(baseURL: accountURL, transport: transport)
            _ = try await client.createAccount(token: token!, AccountCreation(name: name, birthYear: 1990,
                                                                              sbnPath: "/league/\(league.lowercased())/player/\(sbnPlayer)",
                                                                              teamKey: teamKey, consent: true))
        }
        let context = TeamFindingContext(client: AccountClient(baseURL: accountURL, transport: transport), token: token!, teamKey: teamKey)
        return (ScenarioPhone(name: name, context: context, liveURL: liveURL, teamName: home), token!)
    }

    private func teamMatch() -> TeamMatch {
        TeamMatch(date: Date().addingTimeInterval(3600.0), home: home, away: away, ownSide: TeamSide.home, fixtureId: fixture)
    }

    private func registrations(_ phone: ScenarioPhone) async throws -> [TeamLiveListing] {
        try await phone.context.client.teamLives(token: phone.context.token, fixtures: [])
    }

    /// The state of the tracked match: the game under way, after `games` finished games
    private func snapshot(_ own: Int, _ their: Int, games: [[Int]] = []) -> LiveSnapshot {
        var won = [0, 0]
        for game in games { won[game[0] > game[1] ? 0 : 1] += 1 }
        return LiveSnapshot(p1: "Niels", p2: "Wikus", bestOf: 5, games: games, score: [own, their], gamesWon: won, server: 1, side: "R",
                            status: LiveStatus.playing)
    }

    /// The page after the phone's queued send got there
    private func page(_ phone: ScenarioPhone, id: String, until done: (TeamLiveState) -> Bool) async throws -> TeamLiveState {
        var state = try await phone.live.fetch(id: id)
        var tries = 0
        while !done(state) && tries < 40 {
            try await Task.sleep(nanoseconds: 100_000_000)
            state = try await phone.live.fetch(id: id)
            tries += 1
        }
        return state
    }

    // MARK: Scenarios

    /// Start, join by itself, score, close and resume, throw away, delete on the
    /// joined phone, join again with the invitation, delete on the starter's phone
    func testAnEveningOnTwoPhones() async throws {
        let (starter, _) = try await phone("Kristian", sbnPlayer: 939)
        let (mate, _) = try await phone("Gerdjan", sbnPlayer: 940)

        // 1. The starter makes the team match of the programme visible for the team
        let own = teamMatch()
        try await starter.store.save(own)
        let made = try await TeamFinding.makeVisible(own, context: starter.context, store: starter.store, live: starter.live)
        XCTAssertEqual(made.outcome, TeamFindingOutcome.started)
        let liveId = try XCTUnwrap(made.match.liveId)
        XCTAssertTrue(made.match.isLiveOwner)
        XCTAssertTrue(made.match.isTeamOnly)
        let listed = try await registrations(mate)
        XCTAssertEqual(listed.map { listing in listing.liveId }, [liveId], "the teammate finds it through the account")

        // 2. The teammate's phone joins by itself, once, without Meedoen
        let first = await mate.lookForTeamMatches()
        XCTAssertEqual(first.joined.count, 1)
        XCTAssertTrue(first.offers.isEmpty, "no Meedoen for a teammate")
        var mateMatches = try await mate.matches()
        XCTAssertEqual(mateMatches.count, 1)
        XCTAssertEqual(mateMatches[0].liveId, liveId)
        XCTAssertFalse(mateMatches[0].isLiveOwner)
        let again = await mate.lookForTeamMatches()
        XCTAssertTrue(again.joined.isEmpty && again.offers.isEmpty, "a minute later: nothing new")
        // The starter's own phone does not join or get offered its own team match
        let starterLook = await starter.lookForTeamMatches()
        XCTAssertTrue(starterLook.joined.isEmpty && starterLook.offers.isEmpty)
        let starterCount = try await starter.matches()
        XCTAssertEqual(starterCount.count, 1)

        // 3. The starter referees E2: the points reach the page and the teammate's phone
        let matchId = UUID()
        var tracked = try await starter.matches()[0]
        let target = TeamTarget.make(team: tracked, slot: 2, ownIsPlayer1: true, ownName: "Niels van Sevenhoven", opponentName: "Wikus Burger")
        tracked.startTracking(slot: 2, matchId: matchId.uuidString, ownIsPlayer1: true, ownPlayer: target.ownPlayer, opponentPlayer: target.opponentPlayer)
        try await starter.store.save(tracked)
        starter.live.bind(matchId: matchId, teamId: liveId, writeKey: try XCTUnwrap(target.liveKey), slot: 2,
                          homeIsPlayer1: target.homeIsPlayer1, homeLabel: target.homeLabel, awayLabel: target.awayLabel)
        starter.live.forward(matchId: matchId, snapshot: snapshot(3, 2))
        let scored = try await page(starter, id: liveId) { state in state.partijen["2"]?.score == [3, 2] }
        XCTAssertEqual(scored.partijen["2"]?.score, [3, 2])
        // In the first game the page has the points, the teammate's list of partijen not yet:
        // a partij comes into the app with its first finished game (TeamPartij.fromLive)
        _ = try await mate.pull()
        mateMatches = try await mate.matches()
        XCTAssertFalse(mateMatches[0].partij(2).hasEntry)
        starter.live.forward(matchId: matchId, snapshot: snapshot(1, 0, games: [[11, 7]]))
        _ = try await page(starter, id: liveId) { state in state.partijen["2"]?.gamesWon == [1, 0] }
        _ = try await mate.pull()
        mateMatches = try await mate.matches()
        XCTAssertEqual(mateMatches[0].partij(2).fromLive, true, "the teammate sees the partij from the page")
        XCTAssertEqual(mateMatches[0].partij(2).gamesText, "11-7")

        // 4. The starter's app closes: the page is read again, then Hervatten finds the partij
        _ = try await starter.pull()
        let afterPull = try await starter.matches()[0]
        XCTAssertEqual(afterPull.partijTracking(matchId: matchId.uuidString)?.slot, 2, "reading the page keeps the coupling")
        let resumed = await TeamMatchSupport.target(forMatchId: matchId, store: starter.store)
        XCTAssertEqual(resumed?.slot, 2)
        XCTAssertEqual(resumed?.liveId, liveId)
        let fresh = TeamLive(transport: ScenarioTransport())
        fresh.baseURL = liveURL
        fresh.bind(matchId: matchId, teamId: liveId, writeKey: try XCTUnwrap(resumed?.liveKey), slot: 2,
                   homeIsPlayer1: resumed?.homeIsPlayer1 ?? true, homeLabel: resumed?.homeLabel ?? "", awayLabel: resumed?.awayLabel ?? "")
        fresh.forward(matchId: matchId, snapshot: snapshot(7, 5, games: [[11, 7]]))
        let afterResume = try await page(starter, id: liveId) { state in state.partijen["2"]?.score == [7, 5] }
        XCTAssertEqual(afterResume.partijen["2"]?.score, [7, 5], "the resumed match still updates the team page")

        // 5. A match started for E1 and thrown away: E1 is empty again, on the phone and on the page
        let thrownId = UUID()
        var withE1 = try await starter.matches()[0]
        withE1.startTracking(slot: 1, matchId: thrownId.uuidString, ownIsPlayer1: true, ownPlayer: "Gerd-Jan van Gils", opponentPlayer: "Wikus Burger")
        try await starter.store.save(withE1)
        starter.live.bind(matchId: thrownId, teamId: liveId, writeKey: try XCTUnwrap(withE1.liveKey), slot: 1,
                          homeIsPlayer1: true, homeLabel: "Gerd-Jan", awayLabel: "Wikus")
        starter.live.forward(matchId: thrownId, snapshot: LiveSnapshot(p1: "Gerd-Jan", p2: "Wikus", bestOf: 5, games: [], score: [0, 0],
                                                                      gamesWon: [0, 0], server: 1, side: "R", status: LiveStatus.warmup))
        _ = try await page(starter, id: liveId) { state in state.partijen["1"] != nil }
        var dropped = try await starter.matches()[0]
        dropped.stopTracking(matchId: thrownId.uuidString)
        try await starter.store.save(dropped)
        let cleared = await starter.live.clear(slot: 1, in: dropped)
        XCTAssertTrue(cleared)
        XCTAssertEqual(dropped.partij(1).ownPlayer, "", "the names that came with the match are gone")
        let withoutE1 = try await page(starter, id: liveId) { state in state.partijen["1"] == nil }
        XCTAssertNil(withoutE1.partijen["1"], "the page no longer shows E1 warming up")
        XCTAssertNotNil(withoutE1.partijen["2"])

        // 6. The teammate deletes the team match: it stays away, the starter's registration stays
        try await mate.delete(try await mate.matches()[0])
        let afterDelete = await mate.lookForTeamMatches()
        XCTAssertTrue(afterDelete.joined.isEmpty, "not put back a minute later")
        XCTAssertTrue(afterDelete.offers.isEmpty, "and not offered with Meedoen")
        mateMatches = try await mate.matches()
        XCTAssertTrue(mateMatches.isEmpty)
        let stillListed = try await registrations(starter)
        XCTAssertEqual(stillListed.count, 1, "a teammate cannot remove the starter's registration")
        let stillThere = try await starter.live.fetch(id: liveId)
        XCTAssertNotNil(stillThere.partijen["2"], "the page lives on for the starter")

        // 7. Back in with the invitation (the starter's link or code)
        let invite = TeamInvite(id: liveId, key: try XCTUnwrap(dropped.liveKey))
        let state = try await mate.live.fetch(id: liveId)
        var rejoined = TeamMatch.joining(state, invite: invite, ownSide: TeamSide.home)
        rejoined.fixtureId = fixture
        try await mate.store.save(rejoined)
        mateMatches = try await mate.matches()
        XCTAssertEqual(mateMatches.count, 1)
        XCTAssertEqual(mateMatches[0].partij(2).fromLive, true, "what is on the page comes along")

        // 8. The starter deletes: the page and the registration go, the teammate's copy with a partij stays
        try await starter.delete(try await starter.matches()[0])
        let none = try await registrations(mate)
        XCTAssertTrue(none.isEmpty, "the registration went with it")
        do {
            _ = try await starter.live.fetch(id: liveId)
            XCTFail("the page should be gone")
        } catch let error as TeamLiveError {
            XCTAssertEqual(error, TeamLiveError.gone)
        }
        let results = try await mate.pull()
        mateMatches = try await mate.matches()
        XCTAssertEqual(mateMatches.count, 1, "a copy with a partij in it is kept")
        XCTAssertEqual(results[mateMatches[0].id], TeamLiveSyncResult.gone)
    }

    /// The starter deletes right away: the empty copy on the teammate's phone goes with it
    func testAnEmptyCopyDisappearsWhenTheStarterDeletes() async throws {
        let (starter, _) = try await phone("Starter", sbnPlayer: 941)
        let (mate, _) = try await phone("Mate", sbnPlayer: 942)
        let own = teamMatch()
        try await starter.store.save(own)
        let made = try await TeamFinding.makeVisible(own, context: starter.context, store: starter.store, live: starter.live)
        let joined = await mate.lookForTeamMatches()
        XCTAssertEqual(joined.joined.count, 1)
        try await starter.delete(made.match)
        let starterLeft = try await starter.matches()
        XCTAssertTrue(starterLeft.isEmpty)
        let results = try await mate.pull()
        XCTAssertEqual(results.values.first, TeamLiveSyncResult.removed)
        let mateLeft = try await mate.matches()
        XCTAssertTrue(mateLeft.isEmpty, "nothing stays on the teammate's home screen")
        // And nothing comes back by itself
        let later = await mate.lookForTeamMatches()
        XCTAssertTrue(later.joined.isEmpty && later.offers.isEmpty)
    }

    /// The starter's app is reinstalled (a new phone, the same account): the team
    /// match comes back by itself, and deleting it there removes the registration
    func testAfterAReinstallTheStartersTeamMatchComesBackAndCanBeDeleted() async throws {
        let (starter, token) = try await phone("Kristian", sbnPlayer: 943)
        let own = teamMatch()
        try await starter.store.save(own)
        let made = try await TeamFinding.makeVisible(own, context: starter.context, store: starter.store, live: starter.live)
        let liveId = try XCTUnwrap(made.match.liveId)

        // The same account on an empty phone: no owner key there
        let (reinstalled, _) = try await phone("Kristian", sbnPlayer: 943, existingToken: token)
        let look = await reinstalled.lookForTeamMatches()
        XCTAssertEqual(look.joined.count, 1, "the own team match is back without Meedoen")
        XCTAssertTrue(look.offers.isEmpty)
        let copy = try await reinstalled.matches()[0]
        XCTAssertEqual(copy.liveId, liveId)
        XCTAssertFalse(copy.isLiveOwner, "the owner key stayed on the old phone")

        // Deleting it there: the registration goes (this account made it), so nobody finds it again
        try await reinstalled.delete(copy)
        let left = try await registrations(reinstalled)
        XCTAssertTrue(left.isEmpty)
        let after = await reinstalled.lookForTeamMatches()
        XCTAssertTrue(after.joined.isEmpty && after.offers.isEmpty)
    }

    /// Two teammates start the same match at the same moment: they end up on one page
    func testTwoTeammatesWhoBothStartEndUpOnOnePage() async throws {
        let (one, _) = try await phone("Een", sbnPlayer: 944)
        let (two, _) = try await phone("Twee", sbnPlayer: 945)
        let first = teamMatch()
        let second = teamMatch()
        try await one.store.save(first)
        try await two.store.save(second)
        let madeOne = try await TeamFinding.makeVisible(first, context: one.context, store: one.store, live: one.live)
        let madeTwo = try await TeamFinding.makeVisible(second, context: two.context, store: two.store, live: two.live)
        XCTAssertEqual(madeOne.outcome, TeamFindingOutcome.started)
        XCTAssertEqual(madeTwo.outcome, TeamFindingOutcome.joined("Een"))
        XCTAssertEqual(madeTwo.match.liveId, madeOne.match.liveId)
        XCTAssertFalse(madeTwo.match.isLiveOwner)
        let listed = try await registrations(two)
        XCTAssertEqual(listed.count, 1)
        let twoMatches = try await two.matches()
        XCTAssertEqual(twoMatches.count, 1, "the second phone keeps its own team match, now on the first one's page")
    }
}
#endif
