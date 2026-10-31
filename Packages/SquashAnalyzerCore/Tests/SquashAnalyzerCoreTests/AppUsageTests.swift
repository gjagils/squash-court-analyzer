import XCTest
import Foundation
@testable import SquashAnalyzerCore

// The anonymous daily usage count (docs/voorstel-gebruikstelling-app.md): at most
// one "opened" a day, each part once a day, nothing when switched off, and only
// platform, version, language and parts in the request.
final class FakeUsageTransport: LiveTransport, @unchecked Sendable {
    var bodies: [String] = []
    var urls: [String] = []
    var status = 204
    var offline = false

    func send(method: String, url: URL, headers: [String: String], body: Data?) async throws -> AITransportResponse {
        if offline { throw URLError(.notConnectedToInternet) }
        urls.append(url.absoluteString)
        bodies.append(String(data: body ?? Data(), encoding: String.Encoding.utf8) ?? "")
        return AITransportResponse(status: status, body: Data())
    }
}

@MainActor
final class AppUsageTests: XCTestCase {
    private var transport = FakeUsageTransport()

    private func usage() -> AppUsage {
        let defaults = UserDefaults(suiteName: "app-usage-\(UUID().uuidString)")!
        let usage = AppUsage(defaults: defaults)
        transport = FakeUsageTransport()
        usage.transport = transport
        usage.version = "3.1"
        usage.baseURL = "https://live.test"
        return usage
    }

    private func day(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text) ?? Date()
    }

    private func report(_ index: Int) throws -> AppUsageReport {
        try JSONDecoder().decode(AppUsageReport.self, from: Data(transport.bodies[index].utf8))
    }

    func testTheFirstOpeningOfTheDayIsReportedOnce() async throws {
        let usage = usage()
        await usage.appOpened(now: day("2026-11-02 09:00"))
        await usage.appOpened(now: day("2026-11-02 21:30"))
        XCTAssertEqual(transport.bodies.count, 1)
        XCTAssertEqual(transport.urls.first, "https://live.test/api/app/day")
        let first = try report(0)
        XCTAssertEqual(first.platform, AppPlatform.current)
        XCTAssertEqual(first.version, "3.1")
        XCTAssertTrue(first.opened)
        XCTAssertTrue(first.first)
        XCTAssertEqual(first.parts, [String]())
    }

    func testTheNextDayReportsAgainButNotAsFirst() async throws {
        let usage = usage()
        await usage.appOpened(now: day("2026-11-02 09:00"))
        await usage.appOpened(now: day("2026-11-03 08:00"))
        XCTAssertEqual(transport.bodies.count, 2)
        XCTAssertTrue(try report(1).opened)
        XCTAssertFalse(try report(1).first)
    }

    func testAPartIsReportedOnceADayWithoutAnotherOpening() async throws {
        let usage = usage()
        await usage.appOpened(now: day("2026-11-02 09:00"))
        await usage.used(AppUsagePart.referee, now: day("2026-11-02 10:00"))
        await usage.used(AppUsagePart.referee, now: day("2026-11-02 11:00"))
        XCTAssertEqual(transport.bodies.count, 2)
        let part = try report(1)
        XCTAssertFalse(part.opened)
        XCTAssertEqual(part.parts, ["referee"])
        await usage.used(AppUsagePart.referee, now: day("2026-11-03 10:00"))
        XCTAssertEqual(transport.bodies.count, 3)
        XCTAssertTrue(try report(2).opened)
        XCTAssertEqual(try report(2).parts, ["referee"])
    }

    func testAFailedReportIsTriedAgainAtTheNextOpening() async throws {
        let usage = usage()
        transport.offline = true
        await usage.used(AppUsagePart.coach, now: day("2026-11-02 09:00"))
        XCTAssertEqual(transport.bodies.count, 0)
        transport.offline = false
        await usage.appOpened(now: day("2026-11-02 12:00"))
        XCTAssertEqual(transport.bodies.count, 1)
        XCTAssertEqual(try report(0).parts, ["coach"])
        XCTAssertTrue(try report(0).opened)
    }

    func testAServerErrorIsTriedAgainButNotFoundCountsAsDone() async throws {
        let usage = usage()
        transport.status = 503
        await usage.appOpened(now: day("2026-11-02 09:00"))
        await usage.appOpened(now: day("2026-11-02 10:00"))
        XCTAssertEqual(transport.bodies.count, 2)
        transport.status = 404
        await usage.appOpened(now: day("2026-11-02 11:00"))
        await usage.appOpened(now: day("2026-11-02 12:00"))
        XCTAssertEqual(transport.bodies.count, 3)
    }

    func testNothingGoesWhenSwitchedOffOrWithoutTransport() async {
        let defaults = UserDefaults(suiteName: "app-usage-off-\(UUID().uuidString)")!
        defaults.set(false, forKey: AppUsage.enabledKey)
        let off = AppUsage(defaults: defaults)
        let silent = FakeUsageTransport()
        off.transport = silent
        await off.appOpened(now: day("2026-11-02 09:00"))
        await off.used(AppUsagePart.analysis, now: day("2026-11-02 09:00"))
        XCTAssertEqual(silent.bodies.count, 0)

        let none = AppUsage(defaults: UserDefaults(suiteName: "app-usage-none-\(UUID().uuidString)")!)
        XCTAssertTrue(none.isEnabled)
        await none.appOpened(now: day("2026-11-02 09:00"))
    }

    func testTheRequestHoldsOnlyTheAgreedFields() async throws {
        let usage = usage()
        await usage.used(AppUsagePart.competition, now: day("2026-11-02 09:00"))
        let body = transport.bodies[0]
        for key in ["platform", "version", "lang", "parts", "open", "first"] {
            XCTAssertTrue(body.contains("\"\(key)\":"), body)
        }
        XCTAssertEqual(body.components(separatedBy: "\":").count - 1, 6, body)
    }

    func testTheMarketingVersion() {
        XCTAssertEqual(AppUsage.marketingVersion(from: "3.1 (4)"), "3.1")
        XCTAssertEqual(AppUsage.marketingVersion(from: " 3.1 "), "3.1")
        XCTAssertEqual(AppUsage.marketingVersion(from: ""), "unknown")
    }
}
