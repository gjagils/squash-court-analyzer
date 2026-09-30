import XCTest
import Foundation
@testable import SquashAnalyzerCore

final class CardImportTests: XCTestCase {
    /// Made by the iOS app, see `CardSnapshotTests`
    private let iosPayload = "XY9BasMwEEWvUmbtD5alOI53smQvsgq0u5KF2ijFVJEhcZxF8IG66iFysU6IA0kfCIb_Z3joTJ9UUt4Ik1VSQ9lZDdXkKQo9r7AwqRV11kitKkpooFIkFPlg5Y7h5bW__Pj4feDGUfl-po6bpbv87jn54HnbDh5thMO-O3G240xMIGOgpJQolFKYPcCrPavmi_RGQie-bOOhdyFA05jcXG_-y1_DuPF3pQ9-8BGxDZNPT6BioIwxKKy1qB948uX_fdefb-614Deuxz8"

    func testInboxTakesWebAndAppLinks() {
        let inbox = CardInbox()
        XCTAssertTrue(inbox.receive("https://squashanalyzer.com/kaart/#" + iosPayload))
        XCTAssertEqual(inbox.pending?.name, "Paul Stéenks")

        inbox.pending = nil
        XCTAssertTrue(inbox.receive("squashanalyzer://kaart#" + iosPayload))
        XCTAssertEqual(inbox.pending?.awards.count, 2)
    }

    func testInboxIgnoresOtherLinks() {
        let inbox = CardInbox()
        XCTAssertFalse(inbox.receive("https://squashanalyzer.com/badges/"))
        XCTAssertFalse(inbox.receive("https://squashanalyzer.com/kaart/#nietleesbaar"))
        XCTAssertFalse(inbox.receive("https://example.com/kaart/#" + iosPayload))
        XCTAssertNil(inbox.pending)
    }

    func testFinishingAnImportClosesItAndCountsUp() {
        let inbox = CardInbox()
        inbox.receive("https://squashanalyzer.com/kaart/#" + iosPayload)
        XCTAssertEqual(inbox.importCount, 0)
        inbox.finishImport()
        XCTAssertNil(inbox.pending)
        XCTAssertEqual(inbox.importCount, 1)
    }

    func testSummaryUsesTheIOSWording() {
        let hugo = CardImportPlayer(id: "1", name: "Hugo")
        XCTAssertEqual(CardImportPreview(activeBadges: 1, newBadges: 1, deletedBadges: 0, linkedPlayer: nil, players: []).summary,
                       "1 badge op de kaart · 1 nieuw voor jou")
        XCTAssertEqual(CardImportPreview(activeBadges: 4, newBadges: 2, deletedBadges: 1, linkedPlayer: nil, players: []).summary,
                       "4 badges op de kaart · 2 nieuw voor jou · 1 verwijderd")
        XCTAssertEqual(CardImportPreview(activeBadges: 3, newBadges: 0, deletedBadges: 0, linkedPlayer: hugo, players: [hugo]).summary,
                       "3 badges op de kaart · je bent al bij")
    }
}
