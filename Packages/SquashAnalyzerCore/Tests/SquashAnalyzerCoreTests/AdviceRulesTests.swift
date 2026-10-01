import XCTest
import Foundation
@testable import SquashAnalyzerCore

/// The row/side rules of the local advice and their thresholds (docs/plan-lokaal-advies.md)
final class AdviceRulesTests: XCTestCase {
    private func point(_ scorer: Player, _ type: PointType, _ zone: CourtZone?, _ shot: ShotType? = nil, volley: Bool = false) -> Point {
        Point(scorer: scorer, pointType: type, zone: zone, shotType: shot, server: Player.player1,
              player1Score: 0, player2Score: 0, duration: 10, isVolley: volley)
    }

    private func game(_ points: [Point]) -> Game {
        let game = Game()
        game.player1Name = "Gerard"
        game.player2Name = "Thé"
        game.points = points
        return game
    }

    private func texts(_ game: Game, match: Match? = nil) -> [String] {
        var result: [String] = []
        for item in CoachAdvice.local(in: game, for: Player.player1, match: match) {
            result.append(item.text)
        }
        return result
    }

    func testARowNeedsFivePointsThreeThereAndHalf() {
        var tally = AreaTally()
        for zone in [CourtZone.backLeft, CourtZone.backRight, CourtZone.backLeft, CourtZone.frontLeft] {
            tally.add(zone)
        }
        XCTAssertNil(tally.dominantRow, "4 points is too few")
        tally.add(CourtZone.middleRight)
        XCTAssertEqual(tally.dominantRow, CourtRow.back, "3 of 5 is enough")

        var tied = AreaTally()
        for zone in [CourtZone.backLeft, CourtZone.backLeft, CourtZone.backLeft, CourtZone.frontLeft, CourtZone.frontLeft, CourtZone.frontLeft] {
            tied.add(zone)
        }
        XCTAssertNil(tied.dominantRow, "a tie is no pattern")
    }

    func testASideNeedsSeventyPercent() {
        var tally = AreaTally()
        for zone in [CourtZone.frontLeft, CourtZone.backLeft, CourtZone.middleLeft, CourtZone.frontRight, CourtZone.backRight] {
            tally.add(zone)
        }
        XCTAssertNil(tally.dominantSide, "3 of 5 is 60%")
        tally.add(CourtZone.backLeft)
        tally.add(CourtZone.frontLeft)
        XCTAssertEqual(tally.dominantSide, CourtSide.left, "5 of 7 is 71%")
        tally.add(CourtZone.middleMiddle)
        XCTAssertEqual(tally.sideTotal, 7, "the middle column has no side")
    }

    func testStrokesAndServicePointsDoNotCountForZones() {
        let profile = ZoneProfile.of(game([
            point(Player.player1, PointType.stroke, CourtZone.frontLeft),
            point(Player.player1, PointType.servicePoint, CourtZone.backRight),
            point(Player.player1, PointType.winner, CourtZone.frontRight),
            point(Player.player2, PointType.unforcedError, CourtZone.backLeft),
            point(Player.player1, PointType.unforcedError, CourtZone.middleLeft),
        ]), for: Player.player1)
        XCTAssertEqual(profile.won.total, 1)
        XCTAssertEqual(profile.errors.back, 1, "Thé scored on Gerard's error at the back")
        XCTAssertEqual(profile.lost.total, 0)
    }

    func testLostAtTheBackComesFirst() {
        var points: [Point] = []
        for zone in [CourtZone.backLeft, CourtZone.backRight, CourtZone.backLeft, CourtZone.backRight, CourtZone.frontLeft] {
            points.append(point(Player.player2, PointType.winner, zone, ShotType.drive))
        }
        points.append(point(Player.player1, PointType.winner, CourtZone.frontLeft, ShotType.drop))
        let advice = texts(game(points))
        XCTAssertEqual(advice.first, "Je verliest de meeste punten achterin (4 van 5). Thé drukt je naar achteren: werk aan je terugslag uit de achterhoek en speel zelf meer lengte.")
        XCTAssertFalse(advice.contains { $0.hasPrefix("Je verliest de meeste punten aan de") }, "3 of 5 on one side is no side pattern")
    }

    func testOpponentErrorsAreAChanceAndVolleysCount() {
        var points: [Point] = []
        for _ in 0..<3 {
            points.append(point(Player.player1, PointType.unforcedError, CourtZone.frontRight))
        }
        points.append(point(Player.player1, PointType.unforcedError, CourtZone.backRight))
        points.append(point(Player.player1, PointType.unforcedError, CourtZone.backLeft))
        for _ in 0..<3 {
            points.append(point(Player.player2, PointType.winner, CourtZone.middleLeft, ShotType.kill, volley: true))
        }
        let advice = texts(game(points))
        XCTAssertTrue(advice.contains("Thé maakt de meeste fouten voorin (3 van 5). Dwing Thé naar voren."))
        XCTAssertTrue(advice.contains("Thé wint 3 punten uit de lucht. Speel hoger over of strakker langs de muur."))
    }

    func testAtMostFiveLines() {
        var points: [Point] = []
        for zone in [CourtZone.backLeft, CourtZone.backLeft, CourtZone.backLeft, CourtZone.backLeft, CourtZone.frontLeft] {
            points.append(point(Player.player2, PointType.winner, zone, ShotType.drive, volley: true))
        }
        for zone in [CourtZone.frontRight, CourtZone.frontRight, CourtZone.frontRight, CourtZone.frontRight, CourtZone.backRight] {
            points.append(point(Player.player2, PointType.unforcedError, zone))
            points.append(point(Player.player1, PointType.winner, zone, ShotType.drop))
        }
        for _ in 0..<3 {
            points.append(point(Player.player2, PointType.forcedError, CourtZone.middleLeft))
            points.append(point(Player.player2, PointType.servicePoint, nil))
        }
        XCTAssertEqual(texts(game(points)).count, CoachAdvice.maximumItems)
    }

    func testAPatternInAnEarlierGameIsNamed() {
        func losingAtTheBack() -> Game {
            var points: [Point] = []
            for zone in [CourtZone.backLeft, CourtZone.backRight, CourtZone.backLeft, CourtZone.backRight, CourtZone.frontRight] {
                points.append(point(Player.player2, PointType.winner, zone))
            }
            return game(points)
        }
        let match = Match()
        let first = losingAtTheBack()
        let second = losingAtTheBack()
        match.games = [first, second]
        XCTAssertEqual(texts(second, match: match).first,
                       "Je verliest de meeste punten achterin (4 van 5). Thé drukt je naar achteren: werk aan je terugslag uit de achterhoek en speel zelf meer lengte. Net als in game 1.")
        XCTAssertFalse(texts(first, match: match).first?.contains("Net als") ?? true, "the first game has no earlier game")
        XCTAssertEqual(AdviceRules.list([1, 2, 3]), "1, 2 en 3")
    }
}
