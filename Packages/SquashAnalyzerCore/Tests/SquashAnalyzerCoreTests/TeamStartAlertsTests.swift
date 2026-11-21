import XCTest
import Foundation
@testable import SquashAnalyzerCore

@MainActor
final class FakeStartAccount: TeamStartAccount {
    var ready = true
    var online = true
    var puts: [AccountPushToken] = []
    var deletes: [String] = []

    func teamStartReady() async -> Bool { ready }

    func putTeamStartPush(_ push: AccountPushToken) async -> Bool {
        if !online { return false }
        puts.append(push)
        return true
    }

    func deleteTeamStartPush(token: String) async -> Bool {
        if !online { return false }
        deletes.append(token)
        return true
    }
}

/// "Je team is begonnen": the push token of this phone goes to the account
@MainActor
final class TeamStartAlertsTests: XCTestCase {
    private let day = Date(timeIntervalSince1970: 1_793_181_600.0)

    private func fixture(_ platform: FakeAlertPlatform = FakeAlertPlatform()) -> (TeamStartAlerts, TeamAlertFollow, FakeStartAccount, UserDefaults) {
        AppLanguageOverride.shared.language = AppLanguage.dutch
        let defaults = UserDefaults(suiteName: "team-start-\(UUID().uuidString)")!
        let follow = TeamAlertFollow(defaults: defaults)
        follow.platform = platform
        return (TeamStartAlerts(defaults: defaults), follow, FakeStartAccount(), defaults)
    }

    func testTheTokenGoesToTheAccountOnceADay() async {
        let platform = FakeAlertPlatform()
        let (alerts, follow, account, defaults) = fixture(platform)
        await alerts.sync(alerts: follow, account: account, now: day)
        XCTAssertEqual(account.puts, [AccountPushToken(platform: "ios", token: "aa11bb22", sandbox: true, lang: "nl",
                                                       device: LiveDevice.id(in: defaults))])
        XCTAssertEqual(platform.askedWith, [true], "asked for notifications the first time")
        XCTAssertEqual(alerts.sentToken, "aa11bb22")

        await alerts.sync(alerts: follow, account: account, now: day.addingTimeInterval(3600.0))
        XCTAssertEqual(account.puts.count, 1, "the same day: not again")
        await alerts.sync(alerts: follow, account: account, now: day.addingTimeInterval(26.0 * 3600.0))
        XCTAssertEqual(account.puts.count, 2, "the next day: the server sees the phone is still there")
        XCTAssertEqual(platform.askedWith, [true, false, false], "asked only once")
    }

    /// "Teamstand vanzelf op je vergrendelscherm": how the card is started goes with the token
    func testHowTheLockScreenCardIsStartedGoesWithTheTokenAndAgainWhenItChanges() async {
        let platform = FakeAlertPlatform()
        platform.start = "ee55ff66"
        let (alerts, follow, account, _) = fixture(platform)
        await alerts.sync(alerts: follow, account: account, now: day)
        XCTAssertEqual(account.puts.last?.start, "ee55ff66")
        await alerts.sync(alerts: follow, account: account, now: day)
        XCTAssertEqual(account.puts.count, 1, "unchanged: not again")
        // Live Activities switched off: the account hears it the same day
        platform.start = nil
        await alerts.sync(alerts: follow, account: account, now: day)
        XCTAssertEqual(account.puts.count, 2)
        XCTAssertNil(account.puts.last?.start)
        XCTAssertTrue(account.deletes.isEmpty, "the same push token: nothing taken away")
        XCTAssertEqual(alerts.sentToken, "aa11bb22")
        // Not in the body at all without one
        let body = String(data: (try? JSONEncoder().encode(account.puts[1])) ?? Data(), encoding: String.Encoding.utf8) ?? ""
        XCTAssertFalse(body.contains("start"), body)
    }

    func testANewTokenReplacesTheOldOneAndAndroidSendsNoSandbox() async {
        let platform = FakeAlertPlatform(platform: "android")
        let (alerts, follow, account, _) = fixture(platform)
        await alerts.sync(alerts: follow, account: account, now: day)
        XCTAssertNil(account.puts.first?.sandbox)
        platform.token = "cc33dd44"
        await alerts.sync(alerts: follow, account: account, now: day)
        XCTAssertEqual(account.deletes, ["aa11bb22"])
        XCTAssertEqual(account.puts.last?.token, "cc33dd44")
    }

    func testNothingWithoutPermissionAccountOrTeamAndOffTakesTheTokenAway() async {
        let platform = FakeAlertPlatform()
        let (alerts, follow, account, defaults) = fixture(platform)
        platform.allowed = false
        await alerts.sync(alerts: follow, account: account, now: day)
        XCTAssertEqual(account.puts.count, 0, "no notifications: no token")
        platform.allowed = true
        account.ready = false
        await alerts.sync(alerts: follow, account: account, now: day)
        XCTAssertEqual(account.puts.count, 0, "not signed in, or no team")

        account.ready = true
        await alerts.sync(alerts: follow, account: account, now: day)
        XCTAssertEqual(account.puts.count, 1)
        // Instellingen → Live meekijken → Meldingen van je teamwedstrijd off
        defaults.set(false, forKey: TeamAlertFollow.enabledKey)
        account.online = false
        await alerts.sync(alerts: follow, account: account, now: day)
        XCTAssertEqual(alerts.sentToken, "aa11bb22", "no connection: tried again later")
        account.online = true
        await alerts.sync(alerts: follow, account: account, now: day)
        XCTAssertEqual(account.deletes, ["aa11bb22"])
        XCTAssertNil(alerts.sentToken)
    }

    func testTheAccountClientSendsTheTokenAndTakesItAway() async throws {
        let transport = FakeFindingTransport()
        let client = AccountClient(baseURL: "https://account.test", transport: transport)
        try await client.setPushToken(token: "t", AccountPushToken(platform: "android", token: "fcm:1", sandbox: nil, lang: "en", device: "device-aaaa-1111"))
        let put = transport.requests.first { request in request.method == "PUT" && request.url.hasSuffix("/api/v1/me/push") }
        XCTAssertEqual(put?.key, "Bearer t")
        let sent = try JSONDecoder().decode(AccountPushToken.self, from: Data((put?.body ?? "").utf8))
        XCTAssertEqual(sent.token, "fcm:1")
        XCTAssertEqual(sent.lang, "en")
        try await client.removePushToken(token: "t", pushToken: "fcm:1")
        let delete = transport.requests.first { request in request.method == "DELETE" && request.url.hasSuffix("/api/v1/me/push") }
        XCTAssertTrue(delete?.body.contains("fcm:1") == true)
    }
}
