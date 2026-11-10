import Foundation
import XCTest
@testable import SquashAnalyzerCore

final class AccountAvatarsTests: XCTestCase {
    private let path = "/league/x/player/1"

    func testNoPhotoFetchesAnAvatar() {
        XCTAssertEqual(AccountAvatars.step(sbnPath: path, photoChecksum: nil, record: nil, serverVersion: 5),
                       AccountAvatars.Step.fetch(sbnPath: path))
        XCTAssertEqual(AccountAvatars.step(sbnPath: path, photoChecksum: nil, record: nil, serverVersion: nil),
                       AccountAvatars.Step.keep)
    }

    func testOwnPhotoAlwaysWins() {
        XCTAssertEqual(AccountAvatars.step(sbnPath: path, photoChecksum: "mine", record: nil, serverVersion: 5),
                       AccountAvatars.Step.keep)
        // Picked by hand over a fetched photo: forget the record, keep the photo
        let record = AccountAvatarRecord(sbnPath: path, version: 5, checksum: "fetched")
        XCTAssertEqual(AccountAvatars.step(sbnPath: path, photoChecksum: "mine", record: record, serverVersion: 6),
                       AccountAvatars.Step.forget)
    }

    func testFetchedPhotoFollowsTheServer() {
        let record = AccountAvatarRecord(sbnPath: path, version: 5, checksum: "fetched")
        XCTAssertEqual(AccountAvatars.step(sbnPath: path, photoChecksum: "fetched", record: record, serverVersion: 5),
                       AccountAvatars.Step.keep)
        XCTAssertEqual(AccountAvatars.step(sbnPath: path, photoChecksum: "fetched", record: record, serverVersion: 6),
                       AccountAvatars.Step.fetch(sbnPath: path))
        XCTAssertEqual(AccountAvatars.step(sbnPath: path, photoChecksum: "fetched", record: record, serverVersion: nil),
                       AccountAvatars.Step.remove)
    }

    func testARemovedPhotoComesBackOnlyWithANewVersion() {
        let record = AccountAvatarRecord(sbnPath: path, version: 5, checksum: "fetched")
        XCTAssertEqual(AccountAvatars.step(sbnPath: path, photoChecksum: nil, record: record, serverVersion: 5),
                       AccountAvatars.Step.keep)
        XCTAssertEqual(AccountAvatars.step(sbnPath: path, photoChecksum: nil, record: record, serverVersion: 7),
                       AccountAvatars.Step.fetch(sbnPath: path))
    }

    func testRecordsSurviveARestart() {
        let defaults = UserDefaults(suiteName: "avatars-\(UUID().uuidString)")!
        let record = AccountAvatarRecord(sbnPath: path, version: 9, checksum: "abc")
        AccountAvatars.store(["p1": record], in: defaults)
        XCTAssertEqual(AccountAvatars.records(in: defaults)["p1"], record)
        XCTAssertTrue(AccountAvatars.isFetched(playerId: "p1", in: defaults))
        XCTAssertFalse(AccountAvatars.isFetched(playerId: "p2", in: defaults))
    }

    func testOnlyPlainSbnPathsGoInAQuery() {
        XCTAssertTrue(AccountClient.isQuerySafe("/league/2b1c-ab/player/12"))
        XCTAssertFalse(AccountClient.isQuerySafe("/league/x?y=1"))
        XCTAssertFalse(AccountClient.isQuerySafe(""))
    }
}
