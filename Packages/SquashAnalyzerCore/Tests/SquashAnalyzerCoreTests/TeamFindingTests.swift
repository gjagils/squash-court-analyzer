import Foundation
import XCTest
@testable import SquashAnalyzerCore

/// Plays the live Worker and the account Worker for finding a team match (4.0)
final class FakeFindingTransport: LiveTransport, @unchecked Sendable {
    var requests: [TeamRequest] = []
    /// GET /api/v1/me/team/lives answers this list (JSON)
    var lives = "[]"
    /// PUT /api/v1/me/team/lives: 200 (ours) or 409 with `firstListing`
    var registerStatus = 200
    var firstListing = ""
    /// Live team matches the live Worker no longer knows
    var gone: [String] = []
    /// What /verify answers per key
    var roles: [String: String] = [:]
    var stateHome = "Squash City 2"
    var stateAway = "Bevo 3"

    func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> AITransportResponse {
        let text = body.flatMap { String(data: $0, encoding: String.Encoding.utf8) } ?? ""
        let address = url.absoluteString
        requests.append(TeamRequest(method: method, url: address, key: headers["Authorization"] ?? "", body: text))
        let path = url.path
        if path == "/api/v1/me/team/lives" {
            if method == "GET" { return reply(200, "{\"lives\":\(lives)}") }
            if method == "PUT" {
                if registerStatus == 409 { return reply(409, firstListing) }
                let sent = try JSONDecoder().decode(TeamLiveRegistration.self, from: body ?? Data())
                return reply(200, listing(fixture: sent.fixture, liveId: sent.liveId, writeKey: sent.writeKey, own: true))
            }
            return reply(204, "")
        }
        if path == "/api/v1/me/push" { return reply(204, "") }
        if path == "/api/team" && method == "POST" {
            let referee = text.contains("refereeSlots") ? ",\"refereeKey\":\"R3f3r33R3f3r33R3f3r33R3f3r33\"" : ""
            return reply(201, "{\"id\":\"newlive23456\",\"writeKey\":\"N3wK3yN3wK3yN3wK3yN3wK3y\",\"ownerKey\":\"0wn3r0wn3r0wn3r0wn3r0wn3r\",\"url\":\"https://live.test/t/newlive23456\"\(referee)}")
        }
        let parts = path.components(separatedBy: "/")
        if parts.count >= 4 && parts[1] == "api" && parts[2] == "team" {
            let id = parts[3]
            if gone.contains(id) { return reply(404, "{\"error\":\"Onbekende teamwedstrijd\"}") }
            if parts.count == 5 && parts[4] == "verify" {
                let key = (headers["Authorization"] ?? "").replacingOccurrences(of: "Bearer ", with: "")
                guard let role = roles[key] else { return reply(401, "{\"error\":\"Geen toegang\"}") }
                return reply(200, role)
            }
            if parts.count == 4 && method == "GET" {
                return reply(200, "{\"team\":{\"home\":\"\(stateHome)\",\"away\":\"\(stateAway)\",\"date\":1793181600000,\"clubScreen\":false},\"partijen\":{},\"updatedAt\":1}")
            }
            return reply(204, "")
        }
        return reply(404, "{}")
    }

    func listing(fixture: String, liveId: String, writeKey: String?, refereeKey: String? = "R3f3r33R3f3r33R3f3r33R3f3r33",
                 own: Bool, teamName: String = "Squash City 2", starter: String = "Kees") -> String {
        var json = "{\"fixture\":\"\(fixture)\",\"teamName\":\"\(teamName)\",\"liveId\":\"\(liveId)\",\"starterName\":\"\(starter)\",\"matchAt\":1793181600000,\"own\":\(own)"
        if let writeKey { json += ",\"writeKey\":\"\(writeKey)\"" }
        if let refereeKey { json += ",\"refereeKey\":\"\(refereeKey)\"" }
        return json + "}"
    }

    private func reply(_ status: Int, _ text: String) -> AITransportResponse {
        AITransportResponse(status: status, body: text.data(using: String.Encoding.utf8) ?? Data())
    }

    func count(_ method: String, _ part: String) -> Int {
        requests.filter { request in request.method == method && request.url.contains(part) }.count
    }
}

final class TeamFindingTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_793_181_600.0)
    private let league = "0a1b2c3d-0000-4000-8000-0000000000aa"
    private var fixture: String { "/league/\(league)/team-match/9001" }
    private var stored: String { "/league/\(league.uppercased())/team-match/9001" }

    @MainActor private func store() -> JSONFileTeamMatchStore {
        JSONFileTeamMatchStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("finding-\(UUID().uuidString)"))
    }

    private func context(_ transport: FakeFindingTransport) -> TeamFindingContext {
        TeamFindingContext(client: AccountClient(baseURL: "https://account.test", transport: transport), token: "t",
                           teamKey: "\(league.uppercased())/501")
    }

    @MainActor private func live(_ transport: FakeFindingTransport) -> TeamLive {
        let live = TeamLive(transport: transport)
        live.baseURL = "https://live.test"
        return live
    }

    private func ownMatch(side: TeamSide = TeamSide.home) -> TeamMatch {
        TeamMatch(date: day, home: "Squash City 2", away: "Bevo 3", ownSide: side, fixtureId: fixture)
    }

    // MARK: Rules

    @MainActor
    func testTheOpponentRefereesTheOtherHalf() {
        // Home referees match 1 and 3 (E4 and E1), away match 2 and 4 (E2 and E3)
        XCTAssertEqual(TeamFinding.opponentRefereeSlots(keepingSide: TeamSide.home), [2, 3])
        XCTAssertEqual(TeamFinding.opponentRefereeSlots(keepingSide: TeamSide.away), [1, 4])
    }

    @MainActor
    func testTheFixtureIsTheSbnLinkWithTheLeagueInCapitals() {
        XCTAssertEqual(TeamFinding.normalizedFixture(fixture), stored)
        XCTAssertNil(TeamFinding.normalizedFixture("/league/x/team-match/1"))
        XCTAssertNil(TeamFinding.normalizedFixture("https://sbn.toernooi.nl\(fixture)"))
        XCTAssertNil(TeamFinding.normalizedFixture(nil))
    }

    @MainActor
    func testOnlyAMatchOfTheProgrammeInTheOwnLeagueCanBeShared() {
        let transport = FakeFindingTransport()
        XCTAssertTrue(TeamFinding.canShare(ownMatch(), context: context(transport)))
        var typed = ownMatch()
        typed.fixtureId = nil
        XCTAssertFalse(TeamFinding.canShare(typed, context: context(transport)))
        var other = ownMatch()
        other.fixtureId = "/league/0a1b2c3d-0000-4000-8000-0000000000bb/team-match/1"
        XCTAssertFalse(TeamFinding.canShare(other, context: context(transport)))
    }

    func testTheOpponentWritesOnlyItsRefereedPartijen() {
        var match = ownMatch(side: TeamSide.away)
        match.liveId = "abcdefghjkmn"
        match.liveKey = "R3f3r33R3f3r33R3f3r33R3f3r33"
        match.refereeSlots = [2, 3]
        XCTAssertTrue(match.isOpponentCopy)
        XCTAssertTrue(match.mayWriteLive(2))
        XCTAssertFalse(match.mayWriteLive(1))
        XCTAssertNil(TeamTarget.make(team: match, slot: 1).liveId)
        XCTAssertEqual(TeamTarget.make(team: match, slot: 3).liveId, "abcdefghjkmn")
        match.clearLiveState()
        XCTAssertNil(match.refereeSlots)
        XCTAssertFalse(match.isLive)
    }

    // MARK: Making it visible

    @MainActor
    func testANewMatchMakesALiveTeamMatchOffTheClubScreenAndRegistersIt() async throws {
        let transport = FakeFindingTransport()
        let teamStore = store()
        let result = try await TeamFinding.makeVisible(ownMatch(), context: context(transport), store: teamStore, live: live(transport))
        XCTAssertEqual(result.outcome, TeamFindingOutcome.started)
        let create = transport.requests.first { request in request.method == "POST" && request.url.hasSuffix("/api/team") }
        XCTAssertTrue(create?.body.contains("\"clubScreen\":false") == true, create?.body ?? "")
        XCTAssertTrue(create?.body.contains("\"refereeSlots\":[2,3]") == true, create?.body ?? "")
        XCTAssertEqual(result.match.liveId, "newlive23456")
        XCTAssertEqual(result.match.liveOwnerKey, "0wn3r0wn3r0wn3r0wn3r0wn3r")
        XCTAssertEqual(result.match.liveRefereeKey, "R3f3r33R3f3r33R3f3r33R3f3r33")
        XCTAssertTrue(result.match.isTeamOnly)
        let register = transport.requests.first { request in request.method == "PUT" && request.url.contains("/me/team/lives") }
        // Decoded, not searched: Android's encoder writes "/" as "\/"
        let sent = try JSONDecoder().decode(TeamLiveRegistration.self, from: Data((register?.body ?? "").utf8))
        XCTAssertEqual(sent.fixture, stored)
        XCTAssertTrue(register?.body.contains("\"teamName\":\"Squash City 2\"") == true)
        let saved = try await teamStore.loadAll()
        XCTAssertEqual(saved.first?.liveId, "newlive23456")
    }

    @MainActor
    func testAnAwayTeamLetsTheHomeTeamRefereeE1AndE4() async throws {
        let transport = FakeFindingTransport()
        _ = try await TeamFinding.makeVisible(ownMatch(side: TeamSide.away), context: context(transport), store: store(),
                                              live: live(transport))
        let create = transport.requests.first { request in request.method == "POST" && request.url.hasSuffix("/api/team") }
        XCTAssertTrue(create?.body.contains("\"refereeSlots\":[1,4]") == true, create?.body ?? "")
    }

    @MainActor
    func testATeammatesLiveTeamMatchIsJoinedInsteadOfASecondOne() async throws {
        let transport = FakeFindingTransport()
        transport.lives = "[" + transport.listing(fixture: stored, liveId: "keeslive2345", writeKey: "K33sK33sK33sK33sK33sK33s", own: true) + "]"
        transport.roles["K33sK33sK33sK33sK33sK33s"] = "{\"role\":\"writer\"}"
        let result = try await TeamFinding.makeVisible(ownMatch(), context: context(transport), store: store(), live: live(transport))
        XCTAssertEqual(result.outcome, TeamFindingOutcome.joined("Kees"))
        XCTAssertEqual(transport.count("POST", "/api/team"), 0, "no second live team match")
        XCTAssertEqual(result.match.liveId, "keeslive2345")
        XCTAssertEqual(result.match.liveKey, "K33sK33sK33sK33sK33sK33s")
        XCTAssertNil(result.match.liveOwnerKey)
        XCTAssertTrue(result.match.isTeamOnly)
        XCTAssertEqual(result.match.fixtureId, fixture, "the fixture id of this phone stays")
    }

    @MainActor
    func testARegistrationWhoseLiveTeamMatchIsGoneIsReplaced() async throws {
        let transport = FakeFindingTransport()
        transport.lives = "[" + transport.listing(fixture: stored, liveId: "oldlive23456", writeKey: "0ldK3y0ldK3y0ldK3y0ldK3y", own: true) + "]"
        transport.gone = ["oldlive23456"]
        let result = try await TeamFinding.makeVisible(ownMatch(), context: context(transport), store: store(), live: live(transport))
        XCTAssertEqual(result.outcome, TeamFindingOutcome.started)
        let register = transport.requests.first { request in request.method == "PUT" && request.url.contains("/me/team/lives") }
        XCTAssertTrue(register?.body.contains("\"replaces\":\"oldlive23456\"") == true, register?.body ?? "")
    }

    @MainActor
    func testWhenATeammateWasFirstOursGoesAndTheirsIsJoined() async throws {
        let transport = FakeFindingTransport()
        transport.registerStatus = 409
        transport.firstListing = transport.listing(fixture: stored, liveId: "keeslive2345", writeKey: "K33sK33sK33sK33sK33sK33s", own: true)
        transport.roles["K33sK33sK33sK33sK33sK33s"] = "{\"role\":\"writer\"}"
        let result = try await TeamFinding.makeVisible(ownMatch(), context: context(transport), store: store(), live: live(transport))
        XCTAssertEqual(result.outcome, TeamFindingOutcome.joined("Kees"))
        XCTAssertEqual(result.match.liveId, "keeslive2345")
        XCTAssertNil(result.match.liveRefereeKey)
        let stop = transport.requests.first { request in request.method == "DELETE" && request.url.hasSuffix("/api/team/newlive23456") }
        XCTAssertEqual(stop?.key, "Bearer 0wn3r0wn3r0wn3r0wn3r0wn3r", "our own new one is stopped with the owner key")
    }

    // MARK: Finding and joining

    @MainActor
    func testOffersLeaveOutWhatThisPhoneFollowsAndAnOpponentWithoutKey() async {
        let transport = FakeFindingTransport()
        transport.lives = "[" + [
            transport.listing(fixture: stored, liveId: "keeslive2345", writeKey: "K33sK33sK33sK33sK33sK33s", own: true),
            transport.listing(fixture: "/league/X/team-match/2", liveId: "otherlive234", writeKey: nil, refereeKey: nil, own: false),
            transport.listing(fixture: stored, liveId: "followed2345", writeKey: "F0ll0wF0ll0wF0ll0wF0ll0w", own: true),
        ].joined(separator: ",") + "]"
        var followed = ownMatch()
        followed.liveId = "followed2345"
        followed.liveKey = "F0ll0wF0ll0wF0ll0wF0ll0w"
        let programme = [LeagueFixture(id: fixture, date: Date().addingTimeInterval(3600.0), home: "Squash City 2", away: "Bevo 3",
                                       score: nil, url: URL(string: "https://sbn.toernooi.nl\(fixture)")!)]
        let offers = await TeamFinding.offers(context: context(transport), fixtures: programme, matches: [followed])
        XCTAssertEqual(offers.map { offer in offer.liveId }, ["keeslive2345"])
        let asked = transport.requests.first { request in request.method == "GET" && request.url.contains("/me/team/lives") }
        XCTAssertTrue(asked?.url.contains("fixtures=\(stored)") == true, asked?.url ?? "")
    }

    @MainActor
    func testTheOpponentJoinsWithTheRefereeKeyAndSendsOnlyItsPartijen() async throws {
        let transport = FakeFindingTransport()
        transport.roles["R3f3r33R3f3r33R3f3r33R3f3r33"] = "{\"role\":\"referee\",\"slots\":[2,3]}"
        let offer = TeamLiveListing(fixture: stored, teamName: "Squash City 2", liveId: "keeslive2345", writeKey: nil,
                                    refereeKey: "R3f3r33R3f3r33R3f3r33R3f3r33", starterName: "Kees", matchAt: 1_793_181_600_000, own: false)
        let teamLive = live(transport)
        let teamStore = store()
        var match = try await TeamFinding.join(offer, ownTeamName: "Bevo 3", fixtures: [], store: teamStore, live: teamLive)
        XCTAssertEqual(match.ownSide, TeamSide.away)
        XCTAssertEqual(match.refereeSlots, [2, 3])
        XCTAssertEqual(match.liveKey, "R3f3r33R3f3r33R3f3r33R3f3r33")
        XCTAssertTrue(match.isOpponentCopy)

        var refereed = TeamPartij(slot: 2, ownPlayer: "Lisa", opponentPlayer: "Jan")
        XCTAssertTrue(refereed.addGame(TeamGame(own: 11, their: 7)))
        match.update(refereed)
        var other = TeamPartij(slot: 1, ownPlayer: "Mo", opponentPlayer: "Piet")
        XCTAssertTrue(other.addGame(TeamGame(own: 11, their: 9)))
        match.update(other)
        let pushedOwn = await teamLive.push(match.partij(2), in: match)
        let pushedOther = await teamLive.push(match.partij(1), in: match)
        XCTAssertTrue(pushedOwn)
        XCTAssertFalse(pushedOther)
        await teamLive.pushAll(match)
        XCTAssertEqual(transport.count("PUT", "/partij/1"), 0)
        XCTAssertEqual(transport.count("PUT", "/partij/2"), 2)
    }

    @MainActor
    func testAnOwnMatchForTheSameSbnMatchTakesTheOffer() async throws {
        let transport = FakeFindingTransport()
        transport.roles["K33sK33sK33sK33sK33sK33s"] = "{\"role\":\"writer\"}"
        let teamStore = store()
        let mine = ownMatch()
        try await teamStore.save(mine)
        let offer = TeamLiveListing(fixture: stored, teamName: "Squash City 2", liveId: "keeslive2345", writeKey: "K33sK33sK33sK33sK33sK33s",
                                    refereeKey: nil, starterName: "Kees", matchAt: 1_793_181_600_000, own: true)
        let joined = try await TeamFinding.join(offer, ownTeamName: "Squash City 2", fixtures: [], store: teamStore, live: live(transport))
        XCTAssertEqual(joined.id, mine.id)
        XCTAssertEqual(joined.liveId, "keeslive2345")
        XCTAssertNil(joined.refereeSlots)
        let all = try await teamStore.loadAll()
        XCTAssertEqual(all.count, 1)
    }

    // MARK: Joining by itself

    @MainActor
    func testATeammatesLiveTeamMatchIsJoinedByItselfOnceAndTheOpponentsStaysAnOffer() async throws {
        let transport = FakeFindingTransport()
        transport.roles["K33sK33sK33sK33sK33sK33s"] = "{\"role\":\"writer\"}"
        let defaults = UserDefaults(suiteName: "auto-join-\(UUID().uuidString)")!
        let teamStore = store()
        let teamLive = live(transport)
        let own = TeamLiveListing(fixture: stored, teamName: "Squash City 2", liveId: "keeslive2345", writeKey: "K33sK33sK33sK33sK33sK33s",
                                  refereeKey: nil, starterName: "Kees", matchAt: 1_793_181_600_000, own: true)
        let opponent = TeamLiveListing(fixture: "/league/\(league.uppercased())/team-match/9002", teamName: "Bevo 3", liveId: "bevolive2345",
                                       writeKey: nil, refereeKey: "R3f3r33R3f3r33R3f3r33R3f3r33", starterName: "Jan",
                                       matchAt: 1_793_181_600_000, own: false)
        let first = await TeamFinding.joinOwn([own, opponent], ownTeamName: "Squash City 2", fixtures: [], store: teamStore,
                                              live: teamLive, defaults: defaults)
        XCTAssertEqual(first.joined.map { match in match.liveId }, ["keeslive2345"])
        XCTAssertEqual(first.offers.map { offer in offer.liveId }, ["bevolive2345"], "the opponent's still needs Meedoen")
        XCTAssertEqual(TeamFinding.autoJoined(in: defaults), ["keeslive2345"])
        var all = try await teamStore.loadAll()
        XCTAssertEqual(all.count, 1)

        // Deleted on this phone and offered again: not joined a second time, Meedoen is still there
        try await teamStore.delete(id: all[0].id)
        let second = await TeamFinding.joinOwn([own], ownTeamName: "Squash City 2", fixtures: [], store: teamStore,
                                               live: teamLive, defaults: defaults)
        XCTAssertTrue(second.joined.isEmpty)
        XCTAssertEqual(second.offers.map { offer in offer.liveId }, ["keeslive2345"])
        all = try await teamStore.loadAll()
        XCTAssertTrue(all.isEmpty)
    }

    @MainActor
    func testJoiningByItselfTriesAgainAfterNoConnectionAndLeavesAMatchThatIsLiveElsewhere() async throws {
        let transport = FakeFindingTransport()
        transport.roles["K33sK33sK33sK33sK33sK33s"] = "{\"role\":\"writer\"}"
        transport.gone = ["keeslive2345"]
        let defaults = UserDefaults(suiteName: "auto-join-\(UUID().uuidString)")!
        let teamStore = store()
        let teamLive = live(transport)
        let own = TeamLiveListing(fixture: stored, teamName: "Squash City 2", liveId: "keeslive2345", writeKey: "K33sK33sK33sK33sK33sK33s",
                                  refereeKey: nil, starterName: "Kees", matchAt: 1_793_181_600_000, own: true)
        let failed = await TeamFinding.joinOwn([own], ownTeamName: "Squash City 2", fixtures: [], store: teamStore,
                                               live: teamLive, defaults: defaults)
        XCTAssertTrue(failed.joined.isEmpty)
        XCTAssertTrue(failed.offers.isEmpty)
        XCTAssertTrue(TeamFinding.autoJoined(in: defaults).isEmpty, "nothing noted: the next round tries again")

        // This phone has the match live on another page: an offer, so Competitie can explain it
        transport.gone = []
        var mine = ownMatch()
        mine.liveId = "minelive2345"
        mine.liveKey = "M1n3M1n3M1n3M1n3M1n3M1n3"
        try await teamStore.save(mine)
        let elsewhere = await TeamFinding.joinOwn([own], ownTeamName: "Squash City 2", fixtures: [], store: teamStore,
                                                  live: teamLive, defaults: defaults)
        XCTAssertTrue(elsewhere.joined.isEmpty)
        XCTAssertEqual(elsewhere.offers.map { offer in offer.liveId }, ["keeslive2345"])
        XCTAssertEqual(TeamFinding.autoJoined(in: defaults), ["keeslive2345"])
    }

    // MARK: After a match

    @MainActor
    func testAfterAMatchATeammatesLiveTeamMatchOfTodayIsFoundWithoutJoining() async throws {
        let transport = FakeFindingTransport()
        transport.lives = "[" + transport.listing(fixture: stored, liveId: "keeslive2345", writeKey: "K33sK33sK33sK33sK33sK33s", own: true) + "]"
        transport.roles["K33sK33sK33sK33sK33sK33s"] = "{\"role\":\"writer\"}"
        let teamStore = store()
        let found = await TeamFinding.matchDayCandidate(store: teamStore, context: context(transport), live: live(transport), now: day)
        XCTAssertEqual(found?.liveId, "keeslive2345")
        XCTAssertEqual(found?.liveKey, "K33sK33sK33sK33sK33sK33s")
        XCTAssertEqual(found?.ownSide, TeamSide.home)
        XCTAssertEqual(found?.fixtureId, stored)
        let saved = try await teamStore.loadAll()
        XCTAssertEqual(saved.count, 0, "nothing is joined until a partij is chosen")

        // Another day: not asked about
        let later = await TeamFinding.matchDayCandidate(store: teamStore, context: context(transport), live: live(transport),
                                                        now: day.addingTimeInterval(3.0 * 24.0 * 3600.0))
        XCTAssertNil(later)

        // Its live team match is gone: nothing to ask about
        transport.gone = ["keeslive2345"]
        let gone = await TeamFinding.matchDayCandidate(store: teamStore, context: context(transport), live: live(transport), now: day)
        XCTAssertNil(gone)
    }

    @MainActor
    func testAfterAMatchTheOwnMatchOfTodayTakesTheTeammatesLiveTeamMatch() async throws {
        let transport = FakeFindingTransport()
        transport.lives = "[" + transport.listing(fixture: stored, liveId: "keeslive2345", writeKey: "K33sK33sK33sK33sK33sK33s", own: true) + "]"
        transport.roles["K33sK33sK33sK33sK33sK33s"] = "{\"role\":\"writer\"}"
        let teamStore = store()
        let mine = ownMatch()
        try await teamStore.save(mine)
        let found = await TeamFinding.matchDayCandidate(store: teamStore, context: context(transport), live: live(transport), now: day)
        XCTAssertEqual(found?.id, mine.id, "no second team match")
        XCTAssertEqual(found?.liveId, "keeslive2345")
        let saved = try await teamStore.loadAll()
        XCTAssertNil(saved.first?.liveId, "not joined until a partij is chosen")
    }

    @MainActor
    func testAfterAMatchAJoinedTeamMatchIsAskedAboutWithoutTheServer() async throws {
        let transport = FakeFindingTransport()
        let teamStore = store()
        var mine = ownMatch()
        mine.liveId = "keeslive2345"
        mine.liveKey = "K33sK33sK33sK33sK33sK33s"
        try await teamStore.save(mine)
        let found = await TeamFinding.matchDayCandidate(store: teamStore, context: context(transport), live: live(transport), now: day)
        XCTAssertEqual(found?.id, mine.id)
        XCTAssertEqual(transport.count("GET", "/api/v1/me/team/lives"), 0)
    }

    @MainActor
    func testAGoneOfferSaysSo() async {
        let transport = FakeFindingTransport()
        transport.gone = ["keeslive2345"]
        let offer = TeamLiveListing(fixture: stored, teamName: "Squash City 2", liveId: "keeslive2345", writeKey: "K33sK33sK33sK33sK33sK33s",
                                    refereeKey: nil, starterName: "Kees", matchAt: 1_793_181_600_000, own: true)
        do {
            _ = try await TeamFinding.join(offer, ownTeamName: "Squash City 2", fixtures: [], store: store(), live: live(transport))
            XCTFail("a gone live team match cannot be joined")
        } catch {
            XCTAssertEqual(error as? TeamFindingError, TeamFindingError.gone)
        }
    }

    @MainActor
    func testTheOwnerSetsTheRefereedPartijen() async {
        let transport = FakeFindingTransport()
        let teamLive = live(transport)
        var match = ownMatch()
        match.liveId = "newlive23456"
        match.liveKey = "N3wK3yN3wK3yN3wK3yN3wK3y"
        match.liveOwnerKey = "0wn3r0wn3r0wn3r0wn3r0wn3r"
        let slotsSet = await teamLive.setRefereeSlots(match, slots: [3])
        XCTAssertTrue(slotsSet)
        let put = transport.requests.first { request in request.url.hasSuffix("/referee") }
        XCTAssertEqual(put?.body, "{\"slots\":[3]}")
        XCTAssertEqual(put?.key, "Bearer 0wn3r0wn3r0wn3r0wn3r0wn3r")
        let on = await teamLive.setClubScreen(match, on: true)
        XCTAssertTrue(on)
        let header = transport.requests.filter { request in request.method == "PUT" && request.url.hasSuffix("/api/team/newlive23456") }.last
        XCTAssertFalse(header?.body.contains("clubScreen") == true, "on: the field is left out")
        let off = await teamLive.setClubScreen(match, on: false)
        XCTAssertTrue(off)
        let back = transport.requests.filter { request in request.method == "PUT" && request.url.hasSuffix("/api/team/newlive23456") }.last
        XCTAssertTrue(back?.body.contains("\"clubScreen\":false") == true)
    }

    // MARK: Before a match (the question at the start)

    @MainActor
    func testTheStartAsksAboutTheTeamMatchThatIsGoingOn() async throws {
        let matches = store()
        let now = Date()
        let none = await TeamMatchSupport.startCandidate(store: matches, now: now)
        XCTAssertNil(none?.home == "Squash City 2" ? none : nil, "nothing stored: nothing of ours to ask about")

        // Changed an hour ago, played on another day: the home card shows it, so the start asks
        var underWay = ownMatch()
        underWay.updatedAt = now.addingTimeInterval(-3600.0)
        try await matches.save(underWay)
        let asked = await TeamMatchSupport.startCandidate(store: matches, now: now)
        XCTAssertEqual(asked?.id, underWay.id)

        // Decided: a practice game after the team match is not asked about
        var partijen: [TeamPartij] = []
        for slot in 1...4 {
            var partij = TeamPartij(slot: slot)
            for _ in 0..<partij.gamesToWin { partij.games.append(TeamGame(own: 11, their: 5)) }
            partijen.append(partij)
        }
        underWay.partijen = partijen
        try await matches.save(underWay)
        let after = await TeamMatchSupport.startCandidate(store: matches, now: now)
        XCTAssertFalse(after?.id == underWay.id)
    }

    func testOurPlayerFollowsFromThePartijOrTheTeam() {
        let filled = TeamPartij(slot: 2, ownPlayer: "Jan de Vries", opponentPlayer: "Piet Smit")
        XCTAssertEqual(TeamMatchSupport.ownIsPlayer1(partij: filled, player1Name: "Jan de Vries", player2Name: "Piet Smit",
                                                     player1InTeam: false, player2InTeam: false), true)
        XCTAssertEqual(TeamMatchSupport.ownIsPlayer1(partij: filled, player1Name: "Piet", player2Name: "Jan",
                                                     player1InTeam: false, player2InTeam: false), false, "a first name is enough")
        let onlyOpponent = TeamPartij(slot: 2, opponentPlayer: "Piet Smit")
        XCTAssertEqual(TeamMatchSupport.ownIsPlayer1(partij: onlyOpponent, player1Name: "Piet Smit", player2Name: "",
                                                     player1InTeam: false, player2InTeam: false), false)
        let empty = TeamPartij(slot: 2)
        XCTAssertEqual(TeamMatchSupport.ownIsPlayer1(partij: empty, player1Name: "A", player2Name: "B",
                                                     player1InTeam: false, player2InTeam: true), false, "the one player marked In mijn team")
        XCTAssertNil(TeamMatchSupport.ownIsPlayer1(partij: empty, player1Name: "A", player2Name: "B",
                                                   player1InTeam: true, player2InTeam: true), "both in the team: ask")
        XCTAssertNil(TeamMatchSupport.ownIsPlayer1(partij: empty, player1Name: "", player2Name: "",
                                                   player1InTeam: false, player2InTeam: false))
        XCTAssertNil(TeamMatchSupport.ownIsPlayer1(partij: filled, player1Name: "Kees", player2Name: "Henk",
                                                   player1InTeam: false, player2InTeam: false), "other names than the partij: ask")
    }

    @MainActor
    func testATeamMatchFromTheProgrammeIsStoredAtTheStartAndAStoredOneIsLeftAlone() async throws {
        let matches = store()
        var match = ownMatch()
        await TeamMatchSupport.storeForStart(match, store: matches)
        var all = try await matches.loadAll()
        XCTAssertEqual(all.count, 1)

        // Filled in on this phone in the meantime: the copy the setup read earlier does not overwrite it
        var changed = all[0]
        changed.update(TeamPartij(slot: 1, ownPlayer: "Jan", opponentPlayer: "Piet"))
        try await matches.save(changed)
        match.updatedAt = Date()
        await TeamMatchSupport.storeForStart(match, store: matches)
        all = try await matches.loadAll()
        XCTAssertEqual(all[0].partij(1).ownPlayer, "Jan")
    }

    @MainActor
    func testStartingAPartijSharesATeamMatchOfTheProgrammeWithTheTeam() async throws {
        let transport = FakeFindingTransport()
        let matches = store()
        var match = ownMatch()
        match.startTracking(slot: 2, matchId: "tracked-match", ownIsPlayer1: true, ownPlayer: "", opponentPlayer: "")
        try await matches.save(match)
        let shared = await TeamFinding.shareAtStart(teamMatchId: match.id, store: matches, context: context(transport), live: live(transport))
        XCTAssertEqual(shared?.liveId, "newlive23456")
        XCTAssertTrue(shared?.isTeamOnly == true, "for the team only, not on the club screen")
        XCTAssertEqual(shared?.partij(2).trackingMatchId, "tracked-match", "the partij being scored stays coupled")
        XCTAssertEqual(transport.count("PUT", "/me/team/lives"), 1, "registered for the team")
        let target = TeamTarget.make(team: match, slot: 2)
        XCTAssertNil(target.liveId)
        XCTAssertEqual(target.onLive(shared!).liveId, "newlive23456")

        // Live already: nothing happens a second time
        let again = await TeamFinding.shareAtStart(teamMatchId: match.id, store: matches, context: context(transport), live: live(transport))
        XCTAssertNil(again)
        XCTAssertEqual(transport.count("POST", "/api/team"), 1)

        // Typed in by hand (not of the programme): stays on this phone
        var typed = ownMatch()
        typed.fixtureId = nil
        try await matches.save(typed)
        let none = await TeamFinding.shareAtStart(teamMatchId: typed.id, store: matches, context: context(transport), live: live(transport))
        XCTAssertNil(none)
    }

    @MainActor
    func testStartingAPartijJoinsATeammatesLiveTeamMatch() async throws {
        let transport = FakeFindingTransport()
        transport.lives = "[" + transport.listing(fixture: stored, liveId: "keeslive2345", writeKey: "K33sK33sK33sK33sK33sK33s", own: true) + "]"
        transport.roles["K33sK33sK33sK33sK33sK33s"] = "{\"role\":\"writer\"}"
        let matches = store()
        let match = ownMatch()
        try await matches.save(match)
        let shared = await TeamFinding.shareAtStart(teamMatchId: match.id, store: matches, context: context(transport), live: live(transport))
        XCTAssertEqual(shared?.liveId, "keeslive2345")
        XCTAssertEqual(transport.count("POST", "/api/team"), 0, "no second live team match")
    }
}
