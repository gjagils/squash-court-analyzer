import XCTest
import Foundation
@testable import SquashAnalyzerCore

// Simple coaching (Gerd-Jan, 31 October 2026): per point only who and where.
// The point is a `PointType.rally`: one tap on the score, one on the court.
// Enum types are written out in full where Skip needs them (docs/android-port.md).
final class SimpleCoachTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AppLanguageOverride.shared.language = AppLanguage.dutch
    }

    func testScoreAndZoneAddAPoint() {
        let game = Game()
        game.start()
        game.selectPlayer(Player.player1)
        game.selectPointType(PointType.rally)
        XCTAssertEqual(game.scoringStep, Game.ScoringStep.selectZone, "after who comes where")
        game.selectZone(CourtZone.backLeft)
        XCTAssertEqual(game.scoringStep, Game.ScoringStep.selectPlayer, "no shot asked: the point is in")
        XCTAssertEqual(game.player1Score, 1)
        let point = game.points[0]
        XCTAssertEqual(point.pointType, PointType.rally)
        XCTAssertEqual(point.zone, CourtZone.backLeft)
        XCTAssertNil(point.shotType)
    }

    func testDetailedChoicesLeaveOutTheSimplePoint() {
        XCTAssertFalse(PointType.detailed.contains(PointType.rally))
        XCTAssertEqual(PointType.detailed.count, PointType.allCases.count - 1)
    }

    func testZonesCountButNotAsWinners() {
        let game = Game()
        game.addPoint(to: Player.player1, pointType: PointType.rally, at: CourtZone.backLeft, with: nil)
        game.addPoint(to: Player.player1, pointType: PointType.rally, at: CourtZone.backLeft, with: nil)
        game.addPoint(to: Player.player2, pointType: PointType.rally, at: CourtZone.frontRight, with: nil)
        XCTAssertEqual(game.winners(by: Player.player1).count, 0, "not a winner")
        XCTAssertEqual(game.bestZone(for: Player.player1), CourtZone.backLeft)
        let profile = ZoneProfile.of(game, for: Player.player1)
        XCTAssertEqual(profile.won.count(CourtRow.back), 2)
        XCTAssertEqual(profile.lost.count(CourtRow.front), 1, "where the opponent scored")
        XCTAssertEqual(profile.errors.count(CourtRow.front), 0)
    }

    func testMatchKeepsItsMode() {
        let match = Match()
        match.setupMatch(player1: "Bob", player2: "Wim", startingServer: Player.player1)
        XCTAssertEqual(match.inputMode(setting: CoachInputMode.simple), CoachInputMode.simple, "no points yet: the setting")
        match.currentGame.addPoint(to: Player.player1, pointType: PointType.rally, at: CourtZone.frontLeft, with: nil)
        XCTAssertTrue(match.isSimpleInput)
        XCTAssertEqual(match.inputMode(setting: CoachInputMode.detailed), CoachInputMode.simple, "a simple match stays simple")

        let detailed = Match()
        detailed.setupMatch(player1: "Bob", player2: "Wim", startingServer: Player.player1)
        detailed.currentGame.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.frontLeft, with: ShotType.drop)
        XCTAssertEqual(detailed.inputMode(setting: CoachInputMode.simple), CoachInputMode.detailed, "a detailed match stays detailed")
    }

    func testNoErrorFreeBadgesWithoutErrors() {
        let match = Match()
        match.setupMatch(player1: "Bob", player2: "Wim", startingServer: Player.player1)
        match.currentGame.addPoint(to: Player.player1, pointType: PointType.rally, at: CourtZone.frontLeft, with: nil)
        XCTAssertFalse(match.badgeInput.recordsPointTypes, "errors are not kept in simple coaching")
    }

    func testSettingFallsBackToDetailed() {
        XCTAssertEqual(CoachInputMode.from(stored: ""), CoachInputMode.detailed)
        XCTAssertEqual(CoachInputMode.from(stored: "simple"), CoachInputMode.simple)
    }

    func testBackupKeepsTheSimplePoint() {
        let raw = PointExportData(id: nil, pointNumber: 1, scorer: Player.player1.rawValue, pointType: PointType.rally.rawValue,
                                  zone: CourtZone.backLeft.rawValue, shotType: "", server: Player.player1.rawValue,
                                  player1Score: 1, player2Score: 0, duration: 0, timestamp: Date())
        XCTAssertEqual(raw.normalized.pointType, PointType.rally.rawValue)
    }

    func testEnglishTexts() {
        for key in ["Punt", "Alleen wie en waar", "Uitgebreid", "Eenvoudig"] {
            XCTAssertTrue(L10n.hasEnglish(key), key)
        }
    }
}
