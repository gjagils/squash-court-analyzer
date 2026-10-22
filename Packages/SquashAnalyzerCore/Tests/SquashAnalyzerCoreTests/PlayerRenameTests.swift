import XCTest
import Foundation
@testable import SquashAnalyzerCore

// Names can be corrected during a match (Gerd-Jan, 21 October 2026): the
// match, the games played so far, the live snapshot and the calls follow;
// a player picked from Spelers stays linked only under their own name.
// Enum types are written out in full where Skip needs them (docs/android-port.md).
final class PlayerRenameTests: XCTestCase {

    /// These tests check the Dutch texts, whatever language the test machine has
    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }

    // MARK: - Coach

    func testCoachRenameReachesEveryGameAndTheLiveSnapshot() {
        let match = Match()
        match.setupMatch(player1: "Speler 1", player2: "Tim", startingServer: Player.player1)
        match.currentGame.selectPlayer(Player.player1)
        match.currentGame.selectPointType(PointType.unforcedError, errorKind: ErrorKind.down)
        match.startNewGame()
        XCTAssertEqual(match.games.count, 2)

        match.rename(player1: " Bas ", player2: "Tim")

        XCTAssertEqual(match.player1Name, "Bas", "spaces around the name go")
        XCTAssertEqual(match.player2Name, "Tim")
        XCTAssertEqual(match.name(for: Player.player1), "Bas")
        for game in match.games {
            XCTAssertEqual(game.player1Name, "Bas", "the games played so far follow")
            XCTAssertEqual(game.player2Name, "Tim")
        }
        XCTAssertEqual(match.games[0].player1Score, 1, "the points stay")
        XCTAssertEqual(match.liveSnapshot().p1, "Bas")
        XCTAssertEqual(match.liveSnapshot().p2, "Tim")
    }

    func testCoachEmptyNameIsTheDefaultAgain() {
        let match = Match()
        match.setupMatch(player1: "Bas", player2: "Tim", startingServer: Player.player1)
        match.rename(player1: "", player2: "   ")
        XCTAssertEqual(match.player1Name, "Speler 1")
        XCTAssertEqual(match.player2Name, "Speler 2")
        XCTAssertEqual(match.currentGame.player2Name, "Speler 2")
    }

    func testCoachPickedPlayerStaysLinkedOnlyUnderTheirOwnName() {
        let match = Match()
        let basId = UUID()
        let timId = UUID()
        match.setupMatch(player1: "Bas", player2: "Tim", startingServer: Player.player1,
                         player1CoachingFocus: ["Backhand"], player1CoachingNotes: "Rustig blijven",
                         player1Id: basId, player2Id: timId)

        match.rename(player1: "Bas", player2: "Tom")

        XCTAssertEqual(match.player1Id, basId, "the same name: still the picked player")
        XCTAssertEqual(match.player1CoachingFocus, ["Backhand"])
        XCTAssertEqual(match.player1CoachingNotes, "Rustig blijven")
        XCTAssertNil(match.player2Id, "another name is another person")

        match.rename(player1: "Bart", player2: "Tom")

        XCTAssertNil(match.player1Id)
        XCTAssertEqual(match.player1CoachingFocus, [String]())
        XCTAssertEqual(match.player1CoachingNotes, "")
        XCTAssertEqual(match.player1Name, "Bart")
    }

    // MARK: - Referee

    func testRefereeRenameFollowsInTheSnapshotAndTheCalls() {
        let match = RefereeMatch(player1Name: "Speler 1", player2Name: "Speler 2", bestOf: 5, startingServer: Player.player1)
        let id = UUID()
        match.player1Id = id
        match.awardPoint(to: Player.player1)

        match.rename(player1: "Bas", player2: " ")

        XCTAssertEqual(match.name(for: Player.player1), "Bas")
        XCTAssertEqual(match.player2Name, "Speler 2", "empty is the default again")
        XCTAssertNil(match.player1Id, "another name is another person")
        XCTAssertEqual(match.player1Score, 1, "the points stay")
        XCTAssertEqual(match.liveSnapshot.p1, "Bas")
        // The live snapshot shows first names only (LiveSnapshot.firstName), so the default name becomes "Speler"
        XCTAssertEqual(match.liveSnapshot.p2, "Speler")

        match.callStroke(to: Player.player1)
        XCTAssertEqual(match.lastCallText, "STROKE -> BAS")
    }

    func testRefereeSameNameKeepsThePickedPlayer() {
        let match = RefereeMatch(player1Name: "Bas", player2Name: "Tim", bestOf: 5, startingServer: Player.player2)
        let id = UUID()
        match.player2Id = id
        match.rename(player1: "Bas ", player2: "Tim")
        XCTAssertEqual(match.player2Id, id)
        XCTAssertEqual(match.player1Name, "Bas")
    }
}
