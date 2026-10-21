import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// The one-time cleanup of the test period: runs on Darwin and, via Skip, on
/// Android, so both apps offer and remove the same matches.
final class TestDataCleanupTests: XCTestCase {

    /// These tests check the Dutch texts, whatever language the test machine has
    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func match(_ p1: String, _ p2: String, unfinished: Bool = false, at seconds: Double = -3_600) -> TestDataMatch {
        TestDataMatch(startedAt: start.addingTimeInterval(seconds), player1Name: p1, player2Name: p2, isUnfinished: unfinished)
    }

    func testOfferedOnceAfterTheBadgeReset() {
        XCTAssertFalse(TestDataCleanup.shouldOffer(done: false, start: nil, now: start))
        XCTAssertFalse(TestDataCleanup.shouldOffer(done: false, start: start, now: start.addingTimeInterval(-1)))
        XCTAssertTrue(TestDataCleanup.shouldOffer(done: false, start: start, now: start))
        XCTAssertFalse(TestDataCleanup.shouldOffer(done: true, start: start, now: start))
    }

    func testSamplePlayersAreTheOldNamesOnly() {
        XCTAssertTrue(TestDataCleanup.isSamplePlayer("Bombardino"))
        XCTAssertTrue(TestDataCleanup.isSamplePlayer(" whiskey "))
        XCTAssertFalse(TestDataCleanup.isSamplePlayer("Wim"))
        XCTAssertFalse(TestDataCleanup.isSamplePlayer("Bob"))
    }

    func testGroupsOfAMatch() {
        XCTAssertEqual(TestDataCleanup.groups(of: match("Gerd-Jan", "Whiskey"), before: start), [.samplePlayers])
        XCTAssertEqual(TestDataCleanup.groups(of: match("Gerd-Jan", "Paul", unfinished: true), before: start), [.unfinished])
        XCTAssertEqual(TestDataCleanup.groups(of: match("Bombardino", "Paul", unfinished: true), before: start), [.samplePlayers, .unfinished])
        XCTAssertEqual(TestDataCleanup.groups(of: match("Gerd-Jan", "Paul"), before: start), [TestDataGroup]())
        XCTAssertEqual(TestDataCleanup.groups(of: match("Whiskey", "Paul", unfinished: true, at: 60), before: start), [TestDataGroup](), "newer matches stay")
    }

    func testRemovesWhenEitherGroupIsChosen() {
        let both = match("Bombardino", "Paul", unfinished: true)
        XCTAssertTrue(TestDataCleanup.removes(both, chosen: [.unfinished], before: start))
        XCTAssertTrue(TestDataCleanup.removes(both, chosen: [.samplePlayers], before: start))
        XCTAssertFalse(TestDataCleanup.removes(both, chosen: [.competition], before: start))
    }

    func testCounts() {
        let counts = TestDataCleanup.counts(
            matches: [match("Bombardino", "Paul", unfinished: true), match("A", "Whiskey"), match("A", "B", unfinished: true), match("A", "B")],
            teamMatchDates: [start.addingTimeInterval(-86_400), start.addingTimeInterval(86_400)],
            before: start)
        XCTAssertEqual(counts, TestDataCounts(samplePlayers: 2, unfinished: 2, competition: 1))
        XCTAssertEqual(counts.groups, [.samplePlayers, .unfinished, .competition])
        XCTAssertFalse(counts.isEmpty)
        XCTAssertTrue(TestDataCounts().isEmpty)
    }

    /// Badges from before the reset bring the sheet (the message), but nothing to remove
    func testEarlierBadgesShowTheSheetWithoutGroups() {
        let counts = TestDataCleanup.counts(matches: [TestDataMatch](), teamMatchDates: [Date](), before: start, earlierBadges: 3)
        XCTAssertTrue(counts.isEmpty)
        XCTAssertTrue(counts.groups.isEmpty)
        XCTAssertTrue(counts.needsSheet)
        XCTAssertFalse(TestDataCounts().needsSheet, "a new install: no sheet at all")
        XCTAssertTrue(TestDataCounts(unfinished: 1).needsSheet)
    }
}
