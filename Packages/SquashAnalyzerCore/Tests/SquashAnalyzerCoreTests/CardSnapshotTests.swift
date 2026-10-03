import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// Card links must read the same on iPhone, Android and the website. The
/// golden values below were produced by the iOS implementation as it shipped
/// before it moved into this package (JSONEncoder + NSData `.zlib` + base64url,
/// and the SHA-256 award id); these tests run on Darwin and, via Skip, on
/// Android, so both platforms are held to the exact same links and ids.
final class CardSnapshotTests: XCTestCase {
    private let card = UUID(uuidString: "6F1C2B3A-4D5E-4F60-8A7B-9C0D1E2F3A4B")!
    private let match1 = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
    private let match2 = UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!

    private let iosPayload = "XY9BasMwEEWvUmbtD5alOI53smQvsgq0u5KF2ijFVJEhcZxF8IG66iFysU6IA0kfCIb_Z3joTJ9UUt4Ik1VSQ9lZDdXkKQo9r7AwqRV11kitKkpooFIkFPlg5Y7h5bW__Pj4feDGUfl-po6bpbv87jn54HnbDh5thMO-O3G240xMIGOgpJQolFKYPcCrPavmi_RGQie-bOOhdyFA05jcXG_-y1_DuPF3pQ9-8BGxDZNPT6BioIwxKKy1qB948uX_fdefb-614Deuxz8"

    func testReadsALinkMadeByTheIOSApp() throws {
        let snapshot = try CardSnapshot(payload: iosPayload)
        XCTAssertEqual(snapshot.cardId, card)
        XCTAssertEqual(snapshot.name, "Paul Stéenks")
        let awards = snapshot.awards
        XCTAssertEqual(awards.count, 2)

        XCTAssertEqual(awards[0].badge, BadgeKind.fiveInARow)
        XCTAssertEqual(awards[0].matchId, match1)
        XCTAssertEqual(awards[0].earnedAt, Date(timeIntervalSince1970: 1_790_000_000))
        XCTAssertEqual(awards[0].opponentName, "Jaïr")
        XCTAssertEqual(awards[0].awardedBy, "install-A")
        XCTAssertNil(awards[0].deletedAt)

        XCTAssertEqual(awards[1].badge, BadgeKind.elevenNil)
        XCTAssertEqual(awards[1].matchId, match2)
        XCTAssertEqual(awards[1].deletedAt, Date(timeIntervalSince1970: 1_790_001_000))
    }

    func testAwardIdMatchesTheIOSApp() throws {
        let id = AwardValue.awardId(cardId: card, badge: BadgeKind.fiveInARow, matchId: match1)
        XCTAssertEqual(id.uuidString, "3EF839A5-4B4A-5630-97EF-B794B6BCC560")
        let decoded = try CardSnapshot(payload: iosPayload)
        XCTAssertEqual(decoded.awards[0].id, id)
    }

    func testAwardIdDependsOnCardBadgeAndMatch() {
        let base = AwardValue.awardId(cardId: card, badge: BadgeKind.fiveInARow, matchId: match1)
        XCTAssertNotEqual(base, AwardValue.awardId(cardId: card, badge: BadgeKind.fiveInARow, matchId: match2))
        XCTAssertNotEqual(base, AwardValue.awardId(cardId: card, badge: BadgeKind.elevenNil, matchId: match1))
        XCTAssertNotEqual(base, AwardValue.awardId(cardId: match2, badge: BadgeKind.fiveInARow, matchId: match1))
    }

    func testLinkRoundTripsThroughWebAndAppURLs() throws {
        let awards = [
            AwardValue(cardId: card, badge: BadgeKind.houdini, matchId: match1,
                       earnedAt: Date(timeIntervalSince1970: 1_790_000_000), opponentName: "Jaïr",
                       awardedBy: "install-C", deletedAt: nil),
            AwardValue(cardId: card, badge: BadgeKind.perfectTen, matchId: match2,
                       earnedAt: Date(timeIntervalSince1970: 1_790_000_500), opponentName: "",
                       awardedBy: "install-C", deletedAt: Date(timeIntervalSince1970: 1_790_000_900)),
        ]
        let snapshot = CardSnapshot(cardId: card, name: "Hugo", awards: awards)

        let webURL = try snapshot.webURL()
        XCTAssertTrue(webURL.absoluteString.hasPrefix(CardSnapshot.webBase))
        XCTAssertEqual(CardSnapshot(url: webURL), snapshot)
        XCTAssertEqual(CardSnapshot(url: webURL)?.awards, awards)

        let appURL = URL(string: CardSnapshot.appBase + (try snapshot.payload()))!
        XCTAssertEqual(CardSnapshot(url: appURL), snapshot)
    }

    /// A tiny link that unpacks to megabytes is refused, not decompressed in full (T6)
    func testAZipBombIsRefused() throws {
        let zeros = Data(count: 2 * 1024 * 1024)
        let bomb = try CardSnapshot.deflate(zeros).base64EncodedString()
        XCTAssertLessThan(bomb.count, CardSnapshot.maxPayloadLength, "small enough to pass the length check")
        XCTAssertFalse(reads(bomb))
        XCTAssertNil(CardSnapshot(url: URL(string: CardSnapshot.appBase + bomb)!))
    }

    func testATooLongLinkIsRefused() {
        let long = String(repeating: "A", count: CardSnapshot.maxPayloadLength + 4)
        XCTAssertFalse(reads(long))
    }

    /// Whether the payload reads (XCTAssertThrowsError is not in SkipUnit)
    private func reads(_ payload: String) -> Bool {
        do {
            _ = try CardSnapshot(payload: payload)
            return true
        } catch {
            return false
        }
    }

    func testOtherURLsAreNotCards() {
        XCTAssertNil(CardSnapshot(url: URL(string: "https://squashanalyzer.com/privacy.html#abc")!))
        XCTAssertNil(CardSnapshot(url: URL(string: "https://example.com/kaart/#" + iosPayload)!))
        XCTAssertNil(CardSnapshot(url: URL(string: "https://squashanalyzer.com/kaart/")!))
        XCTAssertNil(CardSnapshot(url: URL(string: "https://squashanalyzer.com/kaart/#nietgeldig")!))
    }
}
