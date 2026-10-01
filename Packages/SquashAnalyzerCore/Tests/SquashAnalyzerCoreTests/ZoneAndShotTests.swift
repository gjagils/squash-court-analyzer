import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// 6 or 9 zones, shots per zone row, the volley switch and Kill (the trainer's
/// plan, docs/plan-6-vakken-slagen.md), on Darwin and Android
final class ZoneAndShotTests: XCTestCase {
    func testLayouts() {
        XCTAssertEqual(CourtLayout.six.zones, [CourtZone.frontLeft, CourtZone.frontRight, CourtZone.middleLeft,
                                               CourtZone.middleRight, CourtZone.backLeft, CourtZone.backRight])
        XCTAssertEqual(CourtLayout.nine.zones.count, 9)
        XCTAssertEqual(CourtLayout.from(stored: "nine"), CourtLayout.nine)
        XCTAssertEqual(CourtLayout.from(stored: ""), CourtLayout.six)
        XCTAssertEqual(CourtLayout.from(stored: "iets"), CourtLayout.six)

        XCTAssertEqual(CourtLayout.six.zone(x: 0.1, y: 0.1), CourtZone.frontLeft)
        XCTAssertEqual(CourtLayout.six.zone(x: 0.5, y: 0.5), CourtZone.middleRight)
        XCTAssertEqual(CourtLayout.six.zone(x: 0.99, y: 0.99), CourtZone.backRight)
        XCTAssertEqual(CourtLayout.nine.zone(x: 0.5, y: 0.5), CourtZone.middleMiddle)
        XCTAssertEqual(CourtLayout.nine.zone(x: 1.0, y: 1.0), CourtZone.backRight)

        XCTAssertEqual(CourtLayout.showing([CourtZone.frontLeft, CourtZone.backRight]), CourtLayout.six)
        XCTAssertEqual(CourtLayout.showing([CourtZone.frontLeft, CourtZone.backMiddle]), CourtLayout.nine)
        XCTAssertEqual(CourtZone.backMiddle.row, CourtRow.back)
        XCTAssertTrue(CourtZone.frontMiddle.isMiddleColumn)
        XCTAssertFalse(CourtZone.frontRight.isMiddleColumn)
    }

    func testShotsPerZoneRow() {
        XCTAssertEqual(ShotType.options(for: CourtZone.frontLeft), [ShotType.drop, ShotType.boast, ShotType.kill])
        XCTAssertEqual(ShotType.options(for: CourtZone.frontMiddle), [ShotType.drop, ShotType.boast, ShotType.kill])
        XCTAssertEqual(ShotType.options(for: CourtZone.middleRight), [ShotType.kill, ShotType.drive, ShotType.cross, ShotType.boast])
        XCTAssertEqual(ShotType.options(for: CourtZone.backLeft), [ShotType.drive, ShotType.cross, ShotType.lob])
        XCTAssertEqual(ShotType.options(for: nil), ShotType.selectableCases)
        XCTAssertFalse(ShotType.selectableCases.contains(ShotType.volley))
        XCTAssertTrue(ShotType.volley.isLegacy)
    }

    func testVolleySwitch() {
        XCTAssertTrue(ShotType.drop.allowsVolley)
        XCTAssertFalse(ShotType.lob.allowsVolley)
        XCTAssertEqual(ShotType.drop.displayName(isVolley: true), "Volley drop")
        XCTAssertEqual(ShotType.kill.displayName(isVolley: false), "Kill")
        XCTAssertEqual(ShotType.volley.displayName(isVolley: false), "Volley (oud)")

        let game = Game()
        game.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.frontLeft, with: ShotType.drop, isVolley: true)
        game.addPoint(to: Player.player1, pointType: PointType.winner, at: CourtZone.backLeft, with: ShotType.lob, isVolley: true)
        game.addPoint(to: Player.player1, pointType: PointType.unforcedError, at: nil, with: nil, isVolley: true)
        game.points.append(Point(scorer: Player.player1, shotType: ShotType.volley, server: Player.player1, player1Score: 4, player2Score: 0))
        XCTAssertEqual(game.points.map { point in point.isVolley }, [true, false, false, false])
        XCTAssertEqual(game.volleysWon(by: Player.player1).count, 2)
    }

    private func rally(_ shot: ShotType?, zone: CourtZone? = nil, volley: Bool = false) -> BadgeRally {
        BadgeRally(winner: Player.player1, shot: shot, pointType: PointType.winner, zone: zone, isVolley: volley)
    }

    private func badges(_ rallies: [BadgeRally]) -> Set<BadgeKind> {
        BadgeEngine().badges(for: BadgeMatchInput(games: [BadgeGame(rallies: rallies, winner: nil)]))[Player.player1] ?? []
    }

    func testVolleywoodCountsTheSwitchAndOldVolleys() {
        let mixed = [rally(ShotType.drop, volley: true), rally(ShotType.kill, volley: true), rally(ShotType.volley), rally(ShotType.boast, volley: true)]
        XCTAssertTrue(badges(mixed).contains(BadgeKind.volleywood))
        XCTAssertFalse(badges(Array(mixed.prefix(3))).contains(BadgeKind.volleywood))
    }

    func testFullHouseWithKillOrTheOldSix() {
        let today = ShotType.selectableCases.map { shot in rally(shot) }
        XCTAssertTrue(badges(today).contains(BadgeKind.fullHouse))
        let old = [ShotType.drive, ShotType.cross, ShotType.volley, ShotType.drop, ShotType.lob, ShotType.boast].map { shot in rally(shot) }
        XCTAssertTrue(badges(old).contains(BadgeKind.fullHouse))
        XCTAssertFalse(badges(Array(today.prefix(5))).contains(BadgeKind.fullHouse))
    }

    func testFrontRowKingInBothLayouts() {
        let six = (0..<5).map { index in rally(ShotType.drop, zone: index % 2 == 0 ? CourtZone.frontLeft : CourtZone.frontRight) }
        XCTAssertTrue(badges(six).contains(BadgeKind.frontRowKing))
        let nine = (0..<5).map { _ in rally(ShotType.kill, zone: CourtZone.frontMiddle) }
        XCTAssertTrue(badges(nine).contains(BadgeKind.frontRowKing))
    }
}
