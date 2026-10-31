import XCTest
import Foundation
@testable import SquashAnalyzerCore

// The app names its platform when it starts live sharing or a live team match,
// for the usage counts of the live service (docs/voorstel-gebruikscijfers.md):
// only in that first request, never in an update.
final class LivePlatformTests: XCTestCase {

    func testThePlatformIsIosOrAndroid() {
        XCTAssertTrue(AppPlatform.current == "ios" || AppPlatform.current == "android", AppPlatform.current)
    }

    func testTheTeamHeaderCarriesThePlatformOnlyWhenGiven() throws {
        let with = TeamLiveHeader(home: "A", away: "B", date: 0, lang: "nl", platform: AppPlatform.current)
        let withText = String(data: try JSONEncoder().encode(with), encoding: String.Encoding.utf8) ?? ""
        XCTAssertTrue(withText.contains("\"platform\":\"\(AppPlatform.current)\""), withText)

        let without = TeamLiveHeader(home: "A", away: "B", date: 0)
        let withoutText = String(data: try JSONEncoder().encode(without), encoding: String.Encoding.utf8) ?? ""
        XCTAssertFalse(withoutText.contains("platform"), withoutText)
        XCTAssertEqual(try JSONDecoder().decode(TeamLiveHeader.self, from: Data(withoutText.utf8)), without)
    }

    func testASnapshotUpdateHasNoPlatform() throws {
        var snapshot = LiveSnapshot(p1: "Jan", p2: "Piet", bestOf: 5, games: [], score: [0, 0], gamesWon: [0, 0],
                                    server: 1, side: "R", status: LiveStatus.warmup)
        let update = String(data: try JSONEncoder().encode(snapshot), encoding: String.Encoding.utf8) ?? ""
        XCTAssertFalse(update.contains("platform"), update)
        snapshot.platform = AppPlatform.current
        let first = String(data: try JSONEncoder().encode(snapshot), encoding: String.Encoding.utf8) ?? ""
        XCTAssertTrue(first.contains("\"platform\":\"\(AppPlatform.current)\""), first)
    }
}
