import Foundation
import XCTest
@testable import SquashAnalyzerCore

final class SetupReminderTests: XCTestCase {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "setup-reminder-\(UUID().uuidString)")!
    }

    func testComesBackOnceAfterTwoWeeksWithoutTeamAndAccount() {
        let store = defaults()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertFalse(SetupReminder.check(hasTeam: false, hasAccount: false, now: start, in: store), "first start: only remembered")
        store.set(true, forKey: SetupReminder.teamPromptKey)
        store.set(true, forKey: SetupReminder.accountNudgeKey)
        XCTAssertFalse(SetupReminder.check(hasTeam: false, hasAccount: false, now: start.addingTimeInterval(13 * 86_400), in: store))
        XCTAssertTrue(SetupReminder.check(hasTeam: false, hasAccount: false, now: start.addingTimeInterval(14 * 86_400), in: store))
        XCTAssertFalse(store.bool(forKey: SetupReminder.teamPromptKey), "the SBN card is back")
        XCTAssertFalse(store.bool(forKey: SetupReminder.accountNudgeKey), "the account block is back")
        store.set(true, forKey: SetupReminder.accountNudgeKey)
        XCTAssertFalse(SetupReminder.check(hasTeam: false, hasAccount: false, now: start.addingTimeInterval(30 * 86_400), in: store), "only once")
        XCTAssertTrue(store.bool(forKey: SetupReminder.accountNudgeKey))
    }

    func testNotWithATeamOrAnAccount() {
        XCTAssertFalse(SetupReminder.isDue(firstSeen: 1, now: Int64(30) * Int64(86_400_000), hasTeam: true, hasAccount: false, shown: false))
        XCTAssertFalse(SetupReminder.isDue(firstSeen: 1, now: Int64(30) * Int64(86_400_000), hasTeam: false, hasAccount: true, shown: false))
        XCTAssertTrue(SetupReminder.isDue(firstSeen: 1, now: Int64(30) * Int64(86_400_000), hasTeam: false, hasAccount: false, shown: false))
    }
}
