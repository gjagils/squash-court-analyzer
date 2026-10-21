import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// The badge reset at the production release: runs on Darwin and, via Skip, on
/// Android, so both apps hide the same awards and grant the same Pionier.
final class BadgeSeasonTests: XCTestCase {

    /// These tests check the Dutch texts, whatever language the test machine has
    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private let card = UUID(uuidString: "6F1C2B3A-4D5E-4F60-8A7B-9C0D1E2F3A4B")!
    private let otherCard = UUID(uuidString: "0A1B2C3D-4E5F-4061-8273-8495A6B7C8D9")!
    private let match = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!

    private func award(_ card: UUID, _ badge: BadgeKind, at seconds: Double, deleted: Bool = false) -> AwardValue {
        AwardValue(cardId: card, badge: badge, matchId: match, earnedAt: start.addingTimeInterval(seconds),
                   opponentName: "Paul", awardedBy: "install-A", deletedAt: deleted ? start : nil)
    }

    func testNothingChangesWithoutADate() {
        XCTAssertNil(BadgeSeason.activeStart(start: nil, now: start))
        XCTAssertTrue(BadgeSeason.counts(start.addingTimeInterval(-86_400), start: nil, now: start))
        XCTAssertTrue(BadgeSeason.pioneerCards(among: [award(card, .fiveInARow, at: -60)], start: nil, now: start).isEmpty)
    }

    func testNothingChangesBeforeTheDateHasPassed() {
        let before = start.addingTimeInterval(-1)
        XCTAssertNil(BadgeSeason.activeStart(start: start, now: before))
        XCTAssertTrue(BadgeSeason.counts(start.addingTimeInterval(-86_400), start: start, now: before))
        XCTAssertTrue(BadgeSeason.pioneerCards(among: [award(card, .fiveInARow, at: -60)], start: start, now: before).isEmpty)
    }

    func testFromTheDateOnOlderAwardsNoLongerShow() {
        let now = start.addingTimeInterval(3_600)
        XCTAssertEqual(BadgeSeason.activeStart(start: start, now: now), start)
        XCTAssertFalse(BadgeSeason.shows(earnedAt: start.addingTimeInterval(-1), deletedAt: nil, start: start, now: now))
        XCTAssertTrue(BadgeSeason.shows(earnedAt: start, deletedAt: nil, start: start, now: now))
        XCTAssertFalse(BadgeSeason.shows(earnedAt: start, deletedAt: now, start: start, now: now), "a deleted award never shows")
    }

    func testPioneerGoesToCardsWithAnActiveAwardFromBeforeTheDate() {
        let now = start.addingTimeInterval(3_600)
        let awards = [
            award(card, .fiveInARow, at: -60),
            award(card, .dropIt, at: -30),
            award(otherCard, .fiveInARow, at: -60, deleted: true),
            award(otherCard, .dropIt, at: 60),
        ]
        XCTAssertEqual(BadgeSeason.pioneerCards(among: awards, start: start, now: now), [card])

        // Pionier itself (earned at the start) never makes a card earn it again
        let pioneer = BadgeSeason.pioneerAward(cardId: otherCard, awardedBy: "install-B", start: start)
        XCTAssertTrue(BadgeSeason.pioneerCards(among: [pioneer], start: start, now: now).isEmpty)
    }

    func testPioneerIsTheSameRecordOnEveryDevice() {
        let a = BadgeSeason.pioneerAward(cardId: card, awardedBy: "install-A", start: start)
        let b = BadgeSeason.pioneerAward(cardId: card, awardedBy: "install-B", start: start)
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(a.matchId, BadgeSeason.pioneerMatchId)
        XCTAssertEqual(a.earnedAt, start)
        XCTAssertTrue(BadgeSeason.shows(earnedAt: a.earnedAt, deletedAt: nil, start: start, now: start), "Pionier itself shows")
    }

    func testPioneerIsSpecialAndOutsideTheCollection() {
        XCTAssertTrue(BadgeKind.pioneer.isSpecial)
        XCTAssertEqual(BadgeKind.pioneer.category, BadgeKind.Category.special)
        XCTAssertEqual(BadgeKind.pioneer.title, "Pionier")
        XCTAssertEqual(BadgeKind.pioneer.imageName, "badge-pioneer")
        XCTAssertFalse(BadgeKind.collection.contains(BadgeKind.pioneer))
        XCTAssertTrue(BadgeKind.families.contains(BadgeKind.pioneer))
        XCTAssertFalse(BadgeKind.pioneer.isOnce)
        XCTAssertFalse(BadgeKind.pioneer.isCareer)
    }

    func testAMatchKnowsWhenItBegan() {
        let referee = RefereeMatch(player1Name: "A", player2Name: "B", bestOf: 5, startingServer: .player1, matchStartedAt: start)
        XCTAssertEqual(referee.badgeInput.startedAt, start)
    }
}
