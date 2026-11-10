import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// Records the requests to the live server with their headers
final class FakeAlertTransport: LiveTransport, @unchecked Sendable {
    var requests: [AlertRequest] = []
    var postStatus = 201
    var offline = false

    func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> AITransportResponse {
        if offline { throw URLError(.notConnectedToInternet) }
        var text = ""
        if let body { text = String(data: body, encoding: String.Encoding.utf8) ?? "" }
        requests.append(AlertRequest(method: method, url: url.absoluteString, device: headers[LiveDevice.header] ?? "", body: text))
        if method == "POST" { return AITransportResponse(status: postStatus, body: Data()) }
        return AITransportResponse(status: 204, body: Data())
    }
}

struct AlertRequest {
    let method: String
    let url: String
    let device: String
    let body: String
}

@MainActor
final class FakeAlertPlatform: TeamAlertPlatform {
    let platform: String
    let usesSandbox = true
    var allowed = true
    var token: String? = "aa11bb22"
    var askedWith: [Bool] = []

    init(platform: String = "ios") {
        self.platform = platform
    }

    func notificationsAllowed(ask: Bool) async -> Bool {
        askedWith.append(ask)
        return allowed
    }

    func pushToken() async -> String? { token }
}

/// 4.0, T6: following the live team matches on this phone with notifications
@MainActor
final class TeamAlertFollowTests: XCTestCase {
    private let server = "https://live.test"

    private func fixture(_ platform: FakeAlertPlatform = FakeAlertPlatform()) -> (TeamAlertFollow, FakeAlertTransport, UserDefaults) {
        AppLanguageOverride.shared.language = AppLanguage.dutch
        let defaults = UserDefaults(suiteName: "team-alerts-\(UUID().uuidString)")!
        let follow = TeamAlertFollow(defaults: defaults)
        let transport = FakeAlertTransport()
        follow.transport = transport
        follow.server = server
        follow.platform = platform
        return (follow, transport, defaults)
    }

    private func methods(_ transport: FakeAlertTransport) -> [String] {
        var list: [String] = []
        for request in transport.requests { list.append(request.method) }
        return list
    }

    private func teamIds(_ follow: TeamAlertFollow) -> [String] {
        var list: [String] = []
        for registration in follow.registrations { list.append(registration.teamId) }
        return list
    }

    private func live(_ id: String, updated: Date = Date()) -> TeamMatch {
        TeamMatch(date: Date(), home: "All Inn 8", away: "Delft 8", ownSide: TeamSide.home, updatedAt: updated,
                  liveId: id, liveKey: "K3yK3yK3yK3yK3yK3yK3yK3y")
    }

    func testFollowsTheLiveTeamMatchesAndAsksForPermissionOnce() async {
        let platform = FakeAlertPlatform()
        let (follow, transport, defaults) = fixture(platform)
        let notLive = TeamMatch(date: Date(), home: "A", away: "B", ownSide: TeamSide.home)
        let old = live("oldoldoldold", updated: Date(timeIntervalSinceNow: -2.0 * 24.0 * 3600.0))
        await follow.sync(matches: [live("abcdefghjkmn"), notLive, old])
        XCTAssertEqual(transport.requests.count, 1)
        let request = transport.requests[0]
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url, "https://live.test/api/team/abcdefghjkmn/followers")
        let body = try? JSONDecoder().decode(TeamAlertFollowerBody.self, from: request.body.data(using: String.Encoding.utf8) ?? Data())
        XCTAssertEqual(body?.platform, "ios")
        XCTAssertEqual(body?.token, "aa11bb22")
        XCTAssertEqual(body?.mode, "alerts")
        XCTAssertEqual(body?.sandbox, true)
        XCTAssertEqual(body?.lang, "nl")
        XCTAssertEqual(body?.device, LiveDevice.id(in: defaults))
        XCTAssertEqual(follow.registrations, [TeamAlertRegistration(teamId: "abcdefghjkmn", server: server, token: "aa11bb22", lang: "nl")])
        XCTAssertEqual(platform.askedWith, [true])

        // Again: nothing new is sent, and the user is not asked again
        await follow.sync(matches: [live("abcdefghjkmn")])
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(platform.askedWith, [true, false])
    }

    func testForgetsAMatchThatIsNoLongerLiveHere() async {
        let (follow, transport, _) = fixture()
        await follow.sync(matches: [live("abcdefghjkmn"), live("zyxwvutsrqpn")])
        XCTAssertEqual(follow.registrations.count, 2)
        var left = live("zyxwvutsrqpn")
        left.clearLiveState()
        await follow.sync(matches: [live("abcdefghjkmn"), left])
        let last = transport.requests[transport.requests.count - 1]
        XCTAssertEqual(last.method, "DELETE")
        XCTAssertEqual(last.url, "https://live.test/api/team/zyxwvutsrqpn/followers")
        XCTAssertTrue(last.body.contains("\"mode\":\"alerts\""))
        XCTAssertEqual(teamIds(follow), ["abcdefghjkmn"])
        // Deleted
        await follow.sync(matches: [])
        XCTAssertTrue(follow.registrations.isEmpty)
        XCTAssertEqual(transport.requests[transport.requests.count - 1].method, "DELETE")
    }

    func testTheSettingOffForgetsEverything() async {
        let (follow, transport, defaults) = fixture()
        XCTAssertTrue(follow.isEnabled)
        await follow.sync(matches: [live("abcdefghjkmn")])
        defaults.set(false, forKey: TeamAlertFollow.enabledKey)
        XCTAssertFalse(follow.isEnabled)
        await follow.sync(matches: [live("abcdefghjkmn")])
        XCTAssertTrue(follow.registrations.isEmpty)
        XCTAssertEqual(methods(transport), ["POST", "DELETE"])
        XCTAssertFalse(follow.shouldShow(teamId: "abcdefghjkmn", slot: 0))
    }

    func testWithoutPermissionTokenOrNetworkNothingIsKept() async {
        let platform = FakeAlertPlatform()
        let (follow, transport, _) = fixture(platform)
        platform.allowed = false
        await follow.sync(matches: [live("abcdefghjkmn")])
        XCTAssertEqual(transport.requests.count, 0)
        platform.allowed = true
        platform.token = nil
        await follow.sync(matches: [live("abcdefghjkmn")])
        XCTAssertEqual(transport.requests.count, 0)
        platform.token = "aa11bb22"
        transport.offline = true
        await follow.sync(matches: [live("abcdefghjkmn")])
        XCTAssertTrue(follow.registrations.isEmpty)
        // The server no longer knows it (404): not kept, tried again later
        transport.offline = false
        transport.postStatus = 404
        await follow.sync(matches: [live("abcdefghjkmn")])
        XCTAssertTrue(follow.registrations.isEmpty)
        transport.postStatus = 201
        await follow.sync(matches: [live("abcdefghjkmn")])
        XCTAssertEqual(follow.registrations.count, 1)
    }

    func testANewTokenOrLanguageRegistersAgain() async {
        let platform = FakeAlertPlatform(platform: "android")
        let (follow, transport, _) = fixture(platform)
        await follow.sync(matches: [live("abcdefghjkmn")])
        platform.token = "cc33dd44"
        await follow.sync(matches: [live("abcdefghjkmn")])
        XCTAssertEqual(methods(transport), ["POST", "DELETE", "POST"])
        XCTAssertTrue(transport.requests[1].body.contains("aa11bb22"))
        XCTAssertFalse(transport.requests[2].body.contains("sandbox"))
        XCTAssertEqual(follow.registrations.first?.token, "cc33dd44")
        AppLanguageOverride.shared.language = AppLanguage.english
        await follow.sync(matches: [live("abcdefghjkmn")])
        XCTAssertEqual(follow.registrations.first?.lang, "en")
        XCTAssertEqual(transport.requests.count, 4)
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }

    func testNotShownAboutAPartijFilledInHere() async {
        let (follow, _, _) = fixture()
        var match = live("abcdefghjkmn")
        var own = match.partij(2)
        own.games = [TeamGame(own: 11, their: 5)]
        match.update(own)
        var theirs = match.partij(3)
        theirs.games = [TeamGame(own: 11, their: 5)]
        match.update(theirs)
        // Taken in from the live page (update() makes a partij this phone's own)
        for index in 0..<match.partijen.count where match.partijen[index].slot == 3 { match.partijen[index].fromLive = true }
        await follow.sync(matches: [match])
        XCTAssertTrue(follow.shouldShow(teamId: "abcdefghjkmn", slot: 0))
        XCTAssertTrue(follow.shouldShow(teamId: "abcdefghjkmn", slot: 1))
        XCTAssertFalse(follow.shouldShow(teamId: "abcdefghjkmn", slot: 2))
        XCTAssertTrue(follow.shouldShow(teamId: "abcdefghjkmn", slot: 3))
        XCTAssertTrue(follow.shouldShow(teamId: "otherteamid1", slot: 2))
    }

    func testTheInstallIdStaysTheSame() {
        let defaults = UserDefaults(suiteName: "live-device-\(UUID().uuidString)")!
        let first = LiveDevice.id(in: defaults)
        XCTAssertEqual(first.count, 36)
        XCTAssertEqual(LiveDevice.id(in: defaults), first)
    }

    func testEveryWriteToATeamMatchNamesThisPhone() async {
        let transport = FakeAlertTransport()
        let service = TeamLive(transport: transport)
        service.baseURL = server
        var match = live("abcdefghjkmn")
        var partij = match.partij(1)
        partij.games = [TeamGame(own: 11, their: 5)]
        match.update(partij)
        _ = await service.push(match.partij(1), in: match)
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests[0].method, "PUT")
        XCTAssertEqual(transport.requests[0].device, LiveDevice.id())
    }
}
