import XCTest
import Foundation
@testable import SquashAnalyzerCore

// The SquashLevels link of a player (3.2): only the id is kept, from a pasted
// link or typed in; the page that opens is built here.
final class SquashLevelsTests: XCTestCase {
    func testTheIdFromTheRankingLinkOrTypedIn() {
        // The link Gerd-Jan copied from his browser on 3 November 2026
        let ranking = "https://sbn.squashlevels.com/speelsterkte_ranking?all&page=sbn_rankings&country=8&highlight=286855&show=last10"
        XCTAssertEqual(SquashLevels.playerId(from: ranking), "286855")
        XCTAssertEqual(SquashLevels.playerId(from: " 286855 "), "286855")
        XCTAssertEqual(SquashLevels.playerId(from: "https://www.squashlevels.com/player_detail?player=12345"), "12345")
    }

    func testOtherHostsAndFormsAreRefused() {
        XCTAssertNil(SquashLevels.playerId(from: ""))
        XCTAssertNil(SquashLevels.playerId(from: "http://sbn.squashlevels.com/x?highlight=1"))
        XCTAssertNil(SquashLevels.playerId(from: "https://squashlevels.com.evil.nl/x?highlight=1"))
        XCTAssertNil(SquashLevels.playerId(from: "https://sbn.squashlevels.com:8443/x?highlight=1"))
        XCTAssertNil(SquashLevels.playerId(from: "https://me:pw@sbn.squashlevels.com/x?highlight=1"))
        XCTAssertNil(SquashLevels.playerId(from: "https://sbn.squashlevels.com/x?highlight=abc"))
        XCTAssertNil(SquashLevels.playerId(from: "javascript:alert(1)"))
        XCTAssertNil(SquashLevels.playerId(from: "12345678901"))
    }

    func testTheLinkThatOpens() {
        XCTAssertEqual(SquashLevels.url(forPlayerId: "286855")?.absoluteString,
                       "https://sbn.squashlevels.com/speelsterkte_ranking?all&page=sbn_rankings&country=8&highlight=286855&show=last10")
        XCTAssertNil(SquashLevels.url(forPlayerId: "x"))
    }

    func testTheLinksPerPlayerAndTheBackupMerge() {
        var links = SquashLevelsFile.setting("1", forPlayer: "A", in: [])
        links = SquashLevelsFile.setting("2", forPlayer: "B", in: links)
        links = SquashLevelsFile.setting("3", forPlayer: "A", in: links)
        XCTAssertEqual(links.count, 2)
        links = SquashLevelsFile.setting(nil, forPlayer: "B", in: links)
        XCTAssertEqual(links, [SquashLevelsLink(playerId: "A", levelsId: "3")])

        let incoming = [SquashLevelsLink(playerId: "A", levelsId: "9"), SquashLevelsLink(playerId: "C", levelsId: "7")]
        XCTAssertEqual(SquashLevelsFile.merged(incoming, into: links, replacing: false),
                       [SquashLevelsLink(playerId: "A", levelsId: "3"), SquashLevelsLink(playerId: "C", levelsId: "7")])
        XCTAssertEqual(SquashLevelsFile.merged(incoming, into: links, replacing: true), incoming)
    }

    func testTheFileRoundTrips() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("levels-" + UUID().uuidString)
        let links = [SquashLevelsLink(playerId: "A", levelsId: "286855")]
        try SquashLevelsFile.write(links, in: directory)
        XCTAssertEqual(SquashLevelsFile.read(in: directory), links)
        try? FileManager.default.removeItem(at: directory)
    }

    func testADeletedPlayerLeavesNoLink() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("levels-" + UUID().uuidString)
        let store = SquashLevelsLinks()
        store.configure(directory: directory)
        try store.set("286855", forPlayer: "A")
        try store.set("1001", forPlayer: "B")
        store.forget(player: "A")
        XCTAssertNil(store.levelsId(forPlayer: "A"))
        XCTAssertEqual(store.levelsId(forPlayer: "B"), "1001", "the others stay")
        XCTAssertEqual(SquashLevelsFile.read(in: directory), [SquashLevelsLink(playerId: "B", levelsId: "1001")], "also in the file")
        store.forget(player: "nobody")
        try? FileManager.default.removeItem(at: directory)
    }
}
