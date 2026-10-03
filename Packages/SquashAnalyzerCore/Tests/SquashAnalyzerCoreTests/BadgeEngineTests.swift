import XCTest
import Foundation
@testable import SquashAnalyzerCore

// Ported from SquashAnalyzerTests/BadgeEngineTests.swift as part of the
// Android port's Phase 1 (see docs/android-port.md in the app repo). Two
// tests stayed behind in the app target because they exercise Match/
// RefereeMatch, which are not part of this pure package:
// testRefereeRunCarriesOverIntoTheNextGame and
// testCoachMatchRallyWinnersFollowPlayOrder.
//
// Phase 0's spike found that Skip's Kotlin transpiler can lose the type of a
// bare `.case` shorthand (a) as a dictionary subscript key with no second
// value to anchor inference (e.g. inside XCTAssertNil), and (b) as the second
// operand of `+` between two `Array(repeating:count:)` calls. Those two exact
// shapes are spelled out below with the enum type written in full. Everything
// else keeps the original shorthand; Phase 2 (actually running this file
// through Skip) will surface any further such spots, fixed the same way, not
// guessed at here.
final class BadgeEngineTests: XCTestCase {
    private let engine = BadgeEngine()

    func testFiveInARowIsEarnedOnTheFifthRally() {
        let four = engine.badges(forRallyWinners: Array(repeating: Player.player1, count: 4))
        XCTAssertTrue(four.isEmpty)

        let five = engine.badges(forRallyWinners: Array(repeating: Player.player1, count: 5))
        XCTAssertEqual(five[.player1], [.fiveInARow])
        XCTAssertNil(five[Player.player2])
    }

    func testRunIsBrokenByARallyOfTheOpponent() {
        let winners: [Player] = [.player1, .player1, .player1, .player1, .player2,
                                 .player1, .player1, .player1, .player1]
        XCTAssertTrue(engine.badges(forRallyWinners: winners).isEmpty)
    }

    func testBothPlayersCanEarnTheBadge() {
        let winners = Array(repeating: Player.player1, count: 5) + Array(repeating: Player.player2, count: 6)
        let earned = engine.badges(forRallyWinners: winners)
        XCTAssertEqual(earned[.player1], [.fiveInARow])
        XCTAssertEqual(earned[.player2], [.fiveInARow])
    }

    // MARK: - The other badges

    private func rallies(_ spec: [(Player, Int)], shot: ShotType? = nil, type: PointType? = nil) -> [BadgeRally] {
        spec.flatMap { player, count in Array(repeating: BadgeRally(winner: player, shot: shot, pointType: type), count: count) }
    }

    /// A game from alternating runs, e.g. [(.player2, 5), (.player1, 11)]
    private func game(_ spec: [(Player, Int)]) -> BadgeGame {
        let list = rallies(spec)
        let p1 = list.filter { $0.winner == .player1 }.count, p2 = list.count - p1
        return BadgeGame(rallies: list, winner: ScoringEngine().winner(for: SquashScore(player1: p1, player2: p2)))
    }

    private func input(_ games: [BadgeGame], winner: Player? = nil, before: (Int, Int) = (0, 0)) -> BadgeMatchInput {
        var input = BadgeMatchInput(games: games, player1GamesBefore: before.0, player2GamesBefore: before.1)
        input.player1GamesWon = before.0 + games.filter { $0.winner == .player1 }.count
        input.player2GamesWon = before.1 + games.filter { $0.winner == .player2 }.count
        input.matchWinner = winner
        return input
    }

    /// 11-9 won by `player` without a run of 5 or a big deficit
    private func closeGame(_ player: Player) -> BadgeGame {
        game(Array(repeating: [(player, 1), (player.opponent, 1)], count: 9).flatMap { $0 } + [(player, 2)])
    }

    func testElevenNilAndBackFromTheDead() {
        let earned = engine.badges(for: input([game([(.player1, 11)]), game([(.player2, 5), (.player1, 11)])]))
        XCTAssertTrue(earned[.player1]!.contains(.elevenNil))
        XCTAssertTrue(earned[.player1]!.contains(.backFromTheDeath), "0-5 down, then won")
        XCTAssertFalse(engine.badges(for: input([game([(.player2, 4), (.player1, 11)])]))[.player1]!.contains(.backFromTheDeath))
    }

    func testFourShotsOfAKindInOneGame() {
        var shots = rallies([(.player1, 3)], shot: .drop) + rallies([(.player1, 4)], shot: .cross)
        shots += rallies([(.player1, 4)], shot: .lob) + rallies([(.player2, 4)], type: .servicePoint)
        let earned = engine.badges(for: input([BadgeGame(rallies: shots, winner: .player1)]))
        XCTAssertFalse(earned[.player1]!.contains(.dropIt), "only 3 drops")
        XCTAssertTrue(earned[.player1]!.contains(.krissCross))
        XCTAssertTrue(earned[.player1]!.contains(.lobStory))
        XCTAssertTrue(earned[.player2]!.contains(.aceOfPace))
    }

    func testTenAllGames() {
        let tenAll = game(Array(repeating: [(Player.player1, 1), (Player.player2, 1)], count: 10).flatMap { $0 } + [(Player.player1, 2)])
        XCTAssertTrue(engine.badges(for: input([tenAll]))[.player1]!.contains(.coolUnderPressure))
        XCTAssertFalse(engine.badges(for: input([tenAll]))[.player1]!.contains(.doubleTrouble))
        XCTAssertTrue(engine.badges(for: input([tenAll, tenAll]))[.player1]!.contains(.doubleTrouble))

        let long = game(Array(repeating: [(Player.player1, 1), (Player.player2, 1)], count: 19).flatMap { $0 } + [(Player.player1, 2)])
        XCTAssertTrue(engine.badges(for: input([long]))[.player1]!.contains(.marathonMan), "21-19")
    }

    func testMatchBadges() {
        let sweep = input([closeGame(.player1), closeGame(.player1), closeGame(.player1)], winner: .player1)
        XCTAssertEqual(engine.badges(for: sweep)[.player1], [.cleanSweep, .unbreakable], "never trailed in these 11-9 games")

        let comeback = input([closeGame(.player2), closeGame(.player2), closeGame(.player1), closeGame(.player1), closeGame(.player1)], winner: .player1)
        XCTAssertTrue(engine.badges(for: comeback)[.player1]!.contains(.goingTheDistance))
        XCTAssertFalse(engine.badges(for: comeback)[.player1]!.contains(.cleanSweep))

        let lateStart = input([closeGame(.player1), closeGame(.player1), closeGame(.player1)], winner: .player1, before: (0, 2))
        XCTAssertTrue(engine.badges(for: lateStart)[.player1]!.contains(.goingTheDistance), "picked up at 0-2")
    }

    func testHoudiniSavesThreeMatchPoints() {
        // 0-2 down, the deciding game goes from 7-10 to 12-10 → three match points saved
        let decider = game(Array(repeating: [(Player.player1, 1), (Player.player2, 1)], count: 7).flatMap { $0 } + [(Player.player2, 3), (Player.player1, 5)])
        let match = input([closeGame(.player1), closeGame(.player1), decider], winner: .player1, before: (0, 2))
        XCTAssertEqual(engine.matchPointsSaved(by: .player1, in: match), 3)
        XCTAssertTrue(engine.badges(for: match)[.player1]!.contains(.houdini))
    }

    func testFullHouseNeedsEveryShot() {
        // Today's six shots (the old six with Volley also count: ZoneAndShotTests)
        let shots = ShotType.selectableCases.map { BadgeRally(winner: .player1, shot: $0) }
        XCTAssertTrue(engine.badges(for: input([BadgeGame(rallies: shots, winner: nil)]))[.player1]!.contains(.fullHouse))
        let fewer = shots.dropLast()
        XCTAssertFalse(engine.badges(for: input([BadgeGame(rallies: Array(fewer), winner: nil)]))[.player1]!.contains(.fullHouse))
    }

    func testCareerBadges() {
        func history(_ wins: [Bool], points: Int = 30) -> [BadgeEngine.CareerMatch] {
            wins.enumerated().map { entry in
                BadgeEngine.CareerMatch(matchId: UUID(), date: Date(timeIntervalSince1970: TimeInterval(entry.offset)), won: entry.element, pointsWon: points)
            }
        }
        let first = history([false, true, true, true])
        XCTAssertEqual(engine.careerBadges(in: first[1].matchId, history: first, earnedElsewhere: []), [.offTheMark])
        XCTAssertEqual(engine.careerBadges(in: first[3].matchId, history: first, earnedElsewhere: []), [.hatTrick, .centurion],
                       "third win in a row; 4 × 30 points crosses 100")
        XCTAssertEqual(engine.careerBadges(in: first[3].matchId, history: first, earnedElsewhere: [.centurion]), [.hatTrick])

        let ten = history(Array(repeating: true, count: 10), points: 0)
        XCTAssertTrue(engine.careerBadges(in: ten[9].matchId, history: ten, earnedElsewhere: []).contains(.tenOutOfTen))
        XCTAssertFalse(engine.careerBadges(in: ten[8].matchId, history: ten, earnedElsewhere: []).contains(.tenOutOfTen))

        // T14: 12 wins and no badge yet still earns it; once it is there, not again
        let twelve = history(Array(repeating: true, count: 13), points: 0)
        XCTAssertTrue(engine.careerBadges(in: twelve[12].matchId, history: twelve, earnedElsewhere: []).contains(.tenOutOfTen))
        XCTAssertFalse(engine.careerBadges(in: twelve[12].matchId, history: twelve, earnedElsewhere: [.tenOutOfTen]).contains(.tenOutOfTen))
    }

    // MARK: - Set 05 / 06

    func testPerfectTenAndUnbreakable() {
        let earned = engine.badges(for: input([game([(.player1, 11)])]))
        XCTAssertTrue(earned[.player1]!.isSuperset(of: [BadgeKind.perfectTen, BadgeKind.unbreakable]))
        let trailed = engine.badges(for: input([game([(.player2, 1), (.player1, 11)])]))
        XCTAssertFalse(trailed[.player1]!.contains(.unbreakable), "was 0-1 down")
    }

    func testBrickWallOnlyWithRecordedPointTypes() {
        var rallies = Array(repeating: BadgeRally(winner: .player1, pointType: .winner), count: 11)
        rallies.insert(BadgeRally(winner: .player2, pointType: .winner), at: 3)
        var clean = input([BadgeGame(rallies: rallies, winner: .player1)])
        XCTAssertFalse(engine.badges(for: clean)[.player1]!.contains(.brickWall), "referee mode records no point types")
        clean.recordsPointTypes = true
        XCTAssertTrue(engine.badges(for: clean)[.player1]!.contains(.brickWall))

        rallies[3] = BadgeRally(winner: .player2, pointType: .unforcedError)
        var sloppy = input([BadgeGame(rallies: rallies, winner: .player1)])
        sloppy.recordsPointTypes = true
        XCTAssertFalse(engine.badges(for: sloppy)[.player1]!.contains(.brickWall))
    }

    func testFrontRowKingStrokesAndEndurance() {
        var rallies = Array(repeating: BadgeRally(winner: .player1, pointType: .winner, zone: .frontLeft), count: 4)
        rallies.append(BadgeRally(winner: .player1, pointType: .winner, zone: .frontRight))
        rallies += Array(repeating: BadgeRally(winner: .player2, pointType: .stroke), count: 3)
        let earned = engine.badges(for: input([BadgeGame(rallies: rallies, winner: nil)]))
        XCTAssertTrue(earned[.player1]!.contains(.frontRowKing))
        XCTAssertTrue(earned[.player2]!.contains(.strokeOfGenius))

        let firstLong = [BadgeRally(winner: .player1, duration: 90.0), BadgeRally(winner: .player2, duration: 70.0)]
        XCTAssertNil(engine.badges(for: input([BadgeGame(rallies: firstLong, winner: nil)]))[Player.player1], "first rally never counts")
        XCTAssertNil(engine.badges(for: input([BadgeGame(rallies: firstLong, winner: nil)]))[Player.player2], "70 s is short of 75")
        let secondLong = [BadgeRally(winner: .player2, duration: 5.0), BadgeRally(winner: .player1, duration: 75.0)]
        XCTAssertEqual(engine.badges(for: input([BadgeGame(rallies: secondLong, winner: nil)]))[.player1], [.endurance])
    }

    func testPhotoFinishAndIronMan() {
        var match = input([closeGame(.player1), closeGame(.player2), closeGame(.player1), closeGame(.player2), closeGame(.player1)], winner: .player1)
        XCTAssertTrue(engine.badges(for: match)[.player1]!.contains(.photoFinish))
        XCTAssertFalse(engine.badges(for: match)[.player1]!.contains(.ironMan))
        match.duration = 61.0 * 60.0
        XCTAssertTrue(engine.badges(for: match)[.player1]!.contains(.ironMan))
        XCTAssertTrue(engine.badges(for: match)[.player2]!.contains(.ironMan), "both played it out")
    }

    func testNemesisAndVeteran() {
        let kristian = (0..<5).map { i in
            BadgeEngine.CareerMatch(matchId: UUID(), date: Date(timeIntervalSince1970: TimeInterval(i)), won: true, pointsWon: 0, opponentKey: "kristian")
        }
        XCTAssertTrue(engine.careerBadges(in: kristian[4].matchId, history: kristian, earnedElsewhere: []).contains(.nemesis))
        XCTAssertFalse(engine.careerBadges(in: kristian[3].matchId, history: kristian, earnedElsewhere: []).contains(.nemesis))
        let sixth = kristian + [BadgeEngine.CareerMatch(matchId: UUID(), date: Date(timeIntervalSince1970: 10), won: true, pointsWon: 0, opponentKey: "kristian")]
        XCTAssertFalse(engine.careerBadges(in: sixth[5].matchId, history: sixth, earnedElsewhere: []).contains(.nemesis),
                       "not again against the same opponent")

        let many = (0..<25).map { i in
            BadgeEngine.CareerMatch(matchId: UUID(), date: Date(timeIntervalSince1970: TimeInterval(i)), won: false, pointsWon: 0, opponentKey: "x\(i)")
        }
        XCTAssertEqual(engine.careerBadges(in: many[24].matchId, history: many, earnedElsewhere: []), [.veteran])
        let more = (0..<30).map { i in
            BadgeEngine.CareerMatch(matchId: UUID(), date: Date(timeIntervalSince1970: TimeInterval(i)), won: false, pointsWon: 0, opponentKey: "y\(i)")
        }
        XCTAssertEqual(engine.careerBadges(in: more[29].matchId, history: more, earnedElsewhere: []), [.veteran], "past 25 still")
        XCTAssertTrue(engine.careerBadges(in: more[29].matchId, history: more, earnedElsewhere: [.veteran]).isEmpty)
    }
}
