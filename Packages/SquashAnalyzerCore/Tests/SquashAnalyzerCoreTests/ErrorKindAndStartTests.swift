import XCTest
import Foundation
@testable import SquashAnalyzerCore

// Test feedback October 2026: an unforced error records how it went wrong
// (Down, Out, Service, Via de grond) instead of a zone, and the coach taps
// Start at the first serve so the warm-up never counts as a rally.
// Enum types are written out in full where Skip needs them (docs/android-port.md).
final class ErrorKindAndStartTests: XCTestCase {

    // MARK: - Kind of unforced error

    func testUnforcedErrorRecordsItsKindWithoutAZone() {
        let game = Game()
        game.selectPlayer(Player.player2)
        game.selectPointType(PointType.unforcedError, errorKind: ErrorKind.down)
        XCTAssertEqual(game.player2Score, 1, "no zone step for an unforced error")
        XCTAssertEqual(game.points.last?.errorKind, ErrorKind.down)
        XCTAssertNil(game.points.last?.zone)
        XCTAssertNil(game.points.last?.shotType)
        XCTAssertEqual(game.points.last?.summary, "Unforced error · Down")

        game.selectPlayer(Player.player1)
        game.selectPointType(PointType.unforcedError)
        XCTAssertNil(game.points.last?.errorKind, "nothing picked: unknown")
    }

    func testOnlyUnforcedErrorsKeepAKind() {
        let game = Game()
        game.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive,
                      errorKind: ErrorKind.down)
        XCTAssertNil(game.points.last?.errorKind)
        game.selectPlayer(Player.player1)
        game.selectPointType(PointType.winner, errorKind: ErrorKind.outOfCourt)
        game.selectZone(CourtZone.frontLeft)
        game.addPoint(shotType: ShotType.drop)
        XCTAssertNil(game.points.last?.errorKind)
    }

    func testServiceFaultOnlyWhenTheErrorWasTheServers() {
        let game = Game()
        game.assignStartingServer(Player.player1)
        // Player 2 scores on an error by player 1, who serves
        XCTAssertTrue(game.errorKindOptions(whenScoring: Player.player2).contains(ErrorKind.service))
        // Player 1 scores on an error by the receiver
        XCTAssertFalse(game.errorKindOptions(whenScoring: Player.player1).contains(ErrorKind.service))
        XCTAssertEqual(game.errorKindOptions(whenScoring: Player.player1).count, 3)
    }

    func testErrorKindCountsPerPlayerWhoMadeTheError() {
        let game = Game()
        game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil, errorKind: ErrorKind.down)
        game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil, errorKind: ErrorKind.down)
        game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil, errorKind: ErrorKind.outOfCourt)
        game.addPoint(to: Player.player1, pointType: PointType.unforcedError, at: nil, with: nil, errorKind: ErrorKind.viaFloor)
        game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil)

        let byPlayer1 = game.errorKindCounts(madeBy: Player.player1)
        XCTAssertEqual(byPlayer1[ErrorKind.down], 2)
        XCTAssertEqual(byPlayer1[ErrorKind.outOfCourt], 1)
        XCTAssertNil(byPlayer1[ErrorKind.viaFloor])
        XCTAssertEqual(game.errorKindCounts(madeBy: Player.player2)[ErrorKind.viaFloor], 1)
        XCTAssertEqual(ErrorKind.summary(byPlayer1), "Down 2 · Out 1")
        XCTAssertNil(ErrorKind.summary([:]))
    }

    func testOldUnforcedErrorsWithAZoneStayOffTheZoneCounts() {
        let game = Game()
        game.addPoint(to: Player.player1, pointType: PointType.unforcedError, at: CourtZone.frontLeft, with: nil)
        game.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.frontLeft, with: ShotType.drop)
        XCTAssertEqual(game.pointsWon(by: Player.player1, in: CourtZone.frontLeft), 1)
    }

    func testStoredKindsReadBack() {
        XCTAssertEqual(ErrorKind.from(stored: "Via de grond"), ErrorKind.viaFloor)
        XCTAssertNil(ErrorKind.from(stored: ""))
        XCTAssertNil(ErrorKind.from(stored: nil))
        XCTAssertNil(ErrorKind.from(stored: "Raar"))
    }

    func testBackupKeepsTheKindAndDropsUnknownOnes() {
        let known = PointExportData(id: nil, pointNumber: 1, scorer: "Speler 2", pointType: "Unforced Error", zone: "",
                                    shotType: "", server: "Speler 1", player1Score: 0, player2Score: 1, duration: 3.0,
                                    timestamp: nil, errorKind: "Out")
        XCTAssertEqual(known.normalized.errorKind, "Out")
        let odd = PointExportData(id: nil, pointNumber: 2, scorer: "Speler 2", pointType: "Unforced Error", zone: "",
                                  shotType: "", server: "Speler 1", player1Score: 0, player2Score: 2, duration: 3.0,
                                  timestamp: nil, errorKind: "Smash")
        XCTAssertNil(odd.normalized.errorKind)
    }

    func testAdviceNamesTheErrorThatKeepsComingBack() {
        let game = Game()
        for _ in 0..<3 {
            game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil, errorKind: ErrorKind.down)
        }
        game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil, errorKind: ErrorKind.outOfCourt)
        let texts = AdviceRules.candidates(in: game, for: Player.player1).map { $0.item.text }
        XCTAssertTrue(texts.contains("3× in de tin: mik iets hoger boven de tin."))
        // One error of a kind is no pattern
        let once = Game()
        once.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil, errorKind: ErrorKind.service)
        XCTAssertNil(AdviceRules.mostCommonErrorKind(in: once, madeBy: Player.player1))
    }

    // MARK: - Start of the game

    func testWarmUpDoesNotCountAsTheFirstRally() {
        let game = Game()
        XCTAssertFalse(game.isStarted)
        XCTAssertEqual(game.rallySeconds(), 0.0, "the clock stands still before the start")
        game.lastPointTime = Date().addingTimeInterval(-300.0)  // five minutes of warm-up
        game.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)

        XCTAssertTrue(game.isStarted, "the first point starts the game")
        XCTAssertEqual(game.points.last?.duration, 0.0)
        XCTAssertEqual(game.points.last?.isTimed, false)
        XCTAssertNil(game.averagePointDuration(), "an untimed rally stays out of the statistics")
        XCTAssertNil(game.longestPoint())
    }

    func testStartTapTimesTheFirstRally() {
        let game = Game()
        game.start(at: Date().addingTimeInterval(-12.0))
        XCTAssertTrue(game.isStarted)
        XCTAssertGreaterThanOrEqual(game.rallySeconds(), 12.0)
        game.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        let duration = game.points.last?.duration ?? 0.0
        XCTAssertGreaterThanOrEqual(duration, 12.0)
        XCTAssertLessThan(duration, 15.0)
        XCTAssertEqual(game.averagePointDuration() ?? 0.0, duration, accuracy: 0.001)
    }

    func testUndoingTheFirstPointWithoutStartGoesBackToBeforeTheStart() {
        let game = Game()
        game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil)
        game.undoLastPoint()
        XCTAssertFalse(game.isStarted)

        game.start()
        game.addPoint(to: Player.player2, pointType: PointType.unforcedError, at: nil, with: nil)
        game.undoLastPoint()
        XCTAssertTrue(game.isStarted, "a Start tap stays")
        game.undoStart()
        XCTAssertFalse(game.isStarted)
    }

    func testALetAlsoStartsTheGame() {
        let game = Game()
        game.addLet(requestedBy: Player.player1)
        XCTAssertTrue(game.isStarted)
    }

    func testNextGameWaitsForItsOwnStartSoTheBreakIsNoRally() {
        let match = Match()
        let first = match.currentGame
        first.start()
        for _ in 0..<11 {
            first.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        }
        XCTAssertTrue(first.isGameOver)
        match.onGameEnd()
        XCTAssertFalse(match.currentGame.isStarted)
    }

    func testBadgesSeeNoTimeForAnUntimedRally() {
        let match = Match()
        match.currentGame.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.drive)
        XCTAssertNil(match.badgeInput.games.first?.rallies.first?.duration)
    }
}
