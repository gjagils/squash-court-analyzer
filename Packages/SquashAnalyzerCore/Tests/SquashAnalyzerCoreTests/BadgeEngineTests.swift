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

        // A streak is awarded at 3, 5 and 7 wins in a row, not in every match after
        let streak = history(Array(repeating: true, count: 10), points: 0)
        func hatTrick(_ index: Int) -> [BadgeKind] {
            let got = engine.careerBadges(in: streak[index].matchId, history: streak, earnedElsewhere: [])
            var found: [BadgeKind] = []
            let tiers: [BadgeKind] = [BadgeKind.hatTrick, BadgeKind.hatTrickSilver, BadgeKind.hatTrickGold]
            for kind in tiers where got.contains(kind) { found.append(kind) }
            return found
        }
        let none: [BadgeKind] = []
        XCTAssertEqual(hatTrick(1), none)
        XCTAssertEqual(hatTrick(2), [.hatTrick], "3rd win in a row")
        XCTAssertEqual(hatTrick(3), none, "the 4th does not repeat it")
        XCTAssertEqual(hatTrick(4), [.hatTrickSilver], "5th")
        XCTAssertEqual(hatTrick(6), [.hatTrickGold], "7th")
        XCTAssertEqual(hatTrick(7), none, "8th")
        XCTAssertEqual(hatTrick(9), none, "10th")
        // A new streak after a defeat can earn the bronze again
        let again = history([true, true, true, false, true, true, true])
        XCTAssertTrue(engine.careerBadges(in: again[6].matchId, history: again, earnedElsewhere: []).contains(.hatTrick))

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
        XCTAssertEqual(engine.careerBadges(in: many[24].matchId, history: many, earnedElsewhere: []), [.veteran, .clubicoon], "25 matches against 25 opponents")
        let more = (0..<30).map { i in
            BadgeEngine.CareerMatch(matchId: UUID(), date: Date(timeIntervalSince1970: TimeInterval(i)), won: false, pointsWon: 0, opponentKey: "y\(i)")
        }
        XCTAssertEqual(engine.careerBadges(in: more[29].matchId, history: more, earnedElsewhere: []), [.veteran, .clubicoon], "past 25 still")
        XCTAssertTrue(engine.careerBadges(in: more[29].matchId, history: more, earnedElsewhere: [.veteran, .clubicoon]).isEmpty)
    }

    // MARK: - Tiers and the newer badges

    func testTiersAwardEveryThresholdReached() {
        let eight = engine.badges(for: input([BadgeGame(rallies: rallies([(.player1, 8)], shot: .drop), winner: nil)]))[.player1]!
        XCTAssertTrue(eight.isSuperset(of: [BadgeKind.dropIt, BadgeKind.dropItSilver, BadgeKind.dropItGold]))
        let six = engine.badges(for: input([BadgeGame(rallies: rallies([(.player1, 6)], shot: .drop), winner: nil)]))[.player1]!
        XCTAssertTrue(six.contains(.dropItSilver))
        XCTAssertFalse(six.contains(.dropItGold))

        let seven = engine.badges(forRallyWinners: Array(repeating: Player.player1, count: 7))[.player1]!
        XCTAssertEqual(seven, [.fiveInARow, .fiveInARowSilver])
        XCTAssertEqual(BadgeKind.highestTiers(among: seven), [.fiveInARowSilver])
        XCTAssertEqual(BadgeKind.perfectTen.family, .fiveInARow)
        XCTAssertEqual(BadgeKind.perfectTen.tier, .gold)
        XCTAssertEqual(BadgeKind.perfectTen.imageName, "badge-five-in-a-row-gold")
        XCTAssertEqual(BadgeKind.dropIt.imageName, "badge-drop-it-bronze")
        XCTAssertEqual(BadgeKind.dropItSilver.detail, "6 drops in één game")
        XCTAssertEqual(BadgeKind.rockSolid.imageName, "badge-rock-solid")
        XCTAssertNil(BadgeKind.rockSolid.tier)
        XCTAssertEqual(BadgeKind.families.count, 37)
        XCTAssertEqual(BadgeKind.allCases.count, 71)
    }

    func testBackWallBossHandOutsAndSneltrein() {
        let backWinners = Array(repeating: BadgeRally(winner: .player1, pointType: .winner, zone: .backLeft), count: 5)
        XCTAssertTrue(engine.badges(for: input([BadgeGame(rallies: backWinners, winner: nil)]))[.player1]!.contains(.backWallBoss))

        // Five hand-outs in a row for A: every rally B serves, A wins it back;
        // A loses its own serves in between, which B wins only four times running
        var handOuts: [BadgeRally] = [BadgeRally(winner: .player1, server: .player2), BadgeRally(winner: .player1, server: .player1)]
        for _ in 0..<4 {
            handOuts.append(BadgeRally(winner: .player2, server: .player1))
            handOuts.append(BadgeRally(winner: .player1, server: .player2))
        }
        let earned = engine.badges(for: input([BadgeGame(rallies: handOuts, winner: nil)]))
        XCTAssertTrue(earned[.player1]!.contains(.handOutHeld))
        XCTAssertNil(earned[Player.player2])
        var broken = handOuts
        broken[3] = BadgeRally(winner: .player2, server: .player2)
        XCTAssertNil(engine.badges(for: input([BadgeGame(rallies: broken, winner: nil)]))[Player.player1])

        let quick = BadgeGame(rallies: rallies([(.player1, 11)]), winner: .player1, duration: 5.0 * 60.0)
        XCTAssertTrue(engine.badges(for: input([quick]))[.player1]!.contains(.sneltrein))
        let slow = BadgeGame(rallies: rallies([(.player1, 11)]), winner: .player1, duration: 6.0 * 60.0)
        XCTAssertFalse(engine.badges(for: input([slow]))[.player1]!.contains(.sneltrein))
        XCTAssertFalse(BadgeKind.sneltrein.coachOnly, "referee mode times its games too")
    }

    func testWholeMatchBadgesNeedEveryGameTracked() {
        func blowout(_ player: Player) -> BadgeGame {
            BadgeGame(rallies: rallies([(player, 11), (player.opponent, 3)], type: .winner), winner: player)
        }
        var match = input([blowout(.player1), blowout(.player1), blowout(.player1)], winner: .player1)
        match.recordsPointTypes = true
        let earned = engine.badges(for: match)[.player1]!
        XCTAssertTrue(earned.contains(.vetteWinst))
        XCTAssertTrue(earned.contains(.rockSolid))

        var lateStart = input([blowout(.player1), blowout(.player1)], winner: .player1, before: (1, 0))
        lateStart.recordsPointTypes = true
        XCTAssertFalse(engine.badges(for: lateStart)[.player1]!.contains(.vetteWinst), "the first game was not tracked")
        XCTAssertFalse(engine.badges(for: lateStart)[.player1]!.contains(.rockSolid))

        var sloppy = match
        sloppy.games[1] = BadgeGame(rallies: rallies([(.player1, 11), (.player2, 1)], type: .winner) + rallies([(.player2, 1)], type: .unforcedError), winner: .player1)
        XCTAssertFalse(engine.badges(for: sloppy)[.player1]!.contains(.rockSolid), "one unforced error")
        XCTAssertTrue(engine.badges(for: sloppy)[.player1]!.contains(.vetteWinst))
    }

    func testCareerTiersAndTheNewerCareerBadges() {
        func history(_ count: Int, won: Bool = true, opponent: (Int) -> String) -> [BadgeEngine.CareerMatch] {
            (0..<count).map { i in
                BadgeEngine.CareerMatch(matchId: UUID(), date: Date(timeIntervalSince1970: TimeInterval(i)), won: won, pointsWon: 0, opponentKey: opponent(i))
            }
        }
        let wins = history(25) { _ in "" }
        let silver = engine.careerBadges(in: wins[24].matchId, history: wins, earnedElsewhere: [])
        XCTAssertTrue(silver.isSuperset(of: [BadgeKind.tenOutOfTenSilver, BadgeKind.veteran]))
        XCTAssertFalse(silver.contains(.hatTrickGold), "the 25th win in a row is not the 7th: a long streak is not awarded again")
        XCTAssertFalse(silver.contains(.tenOutOfTenGold))
        XCTAssertFalse(silver.contains(.clubicoon), "no opponent known")

        let rivalry = history(10) { _ in "kristian" }
        XCTAssertTrue(engine.careerBadges(in: rivalry[9].matchId, history: rivalry, earnedElsewhere: []).isSuperset(of: [BadgeKind.rivalen, BadgeKind.nemesisSilver]))
        XCTAssertFalse(engine.careerBadges(in: rivalry[8].matchId, history: rivalry, earnedElsewhere: []).contains(.rivalen))
        XCTAssertFalse(engine.careerBadges(in: rivalry[8].matchId, history: rivalry, earnedElsewhere: []).contains(.nemesisSilver))

        let club = history(10, won: false) { i in "speler \(i)" }
        XCTAssertEqual(engine.careerBadges(in: club[9].matchId, history: club, earnedElsewhere: []), [.clubicoon])
        XCTAssertTrue(engine.careerBadges(in: club[8].matchId, history: club, earnedElsewhere: []).isEmpty)
    }
}
