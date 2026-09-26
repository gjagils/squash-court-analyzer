import XCTest
@testable import SquashAnalyzer

final class BadgeEngineTests: XCTestCase {
    private let engine = BadgeEngine()

    func testFiveInARowIsEarnedOnTheFifthRally() {
        let four = engine.badges(forRallyWinners: Array(repeating: .player1, count: 4))
        XCTAssertTrue(four.isEmpty)

        let five = engine.badges(forRallyWinners: Array(repeating: .player1, count: 5))
        XCTAssertEqual(five[.player1], [.fiveInARow])
        XCTAssertNil(five[.player2])
    }

    func testRunIsBrokenByARallyOfTheOpponent() {
        let winners: [Player] = [.player1, .player1, .player1, .player1, .player2,
                                 .player1, .player1, .player1, .player1]
        XCTAssertTrue(engine.badges(forRallyWinners: winners).isEmpty)
    }

    func testBothPlayersCanEarnTheBadge() {
        let winners = Array(repeating: Player.player1, count: 5) + Array(repeating: .player2, count: 6)
        let earned = engine.badges(forRallyWinners: winners)
        XCTAssertEqual(earned[.player1], [.fiveInARow])
        XCTAssertEqual(earned[.player2], [.fiveInARow])
    }

    func testRefereeRunCarriesOverIntoTheNextGame() {
        let match = RefereeMatch(player1Name: "A", player2Name: "B", bestOf: 5, startingServer: .player1)
        for _ in 0..<10 {                                   // alternate to 10-10, no runs
            match.awardPoint(to: .player1)
            match.awardPoint(to: .player2)
        }
        for _ in 0..<2 { match.awardPoint(to: .player1) }   // 12-10: A ends game 1 with 2 in a row
        match.confirmNextGame()
        for _ in 0..<3 { match.awardPoint(to: .player1) }   // ...and adds 3 in game 2

        let earned = engine.badges(forRallyWinners: match.rallyWinners)
        XCTAssertEqual(match.completedGames.count, 1)
        XCTAssertEqual(earned[.player1], [.fiveInARow])
        XCTAssertNil(earned[.player2])
    }

    func testCoachMatchRallyWinnersFollowPlayOrder() {
        let match = Match()
        for _ in 0..<5 { match.currentGame.addPoint(to: .player2, pointType: .winner, at: nil, with: nil) }
        XCTAssertEqual(engine.badges(forRallyWinners: match.rallyWinners)[.player2], [.fiveInARow])
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
        let tenAll = game(Array(repeating: [(.player1, 1), (.player2, 1)], count: 10).flatMap { $0 } + [(.player1, 2)])
        XCTAssertTrue(engine.badges(for: input([tenAll]))[.player1]!.contains(.coolUnderPressure))
        XCTAssertFalse(engine.badges(for: input([tenAll]))[.player1]!.contains(.doubleTrouble))
        XCTAssertTrue(engine.badges(for: input([tenAll, tenAll]))[.player1]!.contains(.doubleTrouble))

        let long = game(Array(repeating: [(.player1, 1), (.player2, 1)], count: 19).flatMap { $0 } + [(.player1, 2)])
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
        let decider = game(Array(repeating: [(.player1, 1), (.player2, 1)], count: 7).flatMap { $0 } + [(.player2, 3), (.player1, 5)])
        let match = input([closeGame(.player1), closeGame(.player1), decider], winner: .player1, before: (0, 2))
        XCTAssertEqual(engine.matchPointsSaved(by: .player1, in: match), 3)
        XCTAssertTrue(engine.badges(for: match)[.player1]!.contains(.houdini))
    }

    func testFullHouseNeedsEveryShot() {
        let shots = ShotType.allCases.map { BadgeRally(winner: .player1, shot: $0) }
        XCTAssertTrue(engine.badges(for: input([BadgeGame(rallies: shots, winner: nil)]))[.player1]!.contains(.fullHouse))
        let fewer = shots.dropLast()
        XCTAssertFalse(engine.badges(for: input([BadgeGame(rallies: Array(fewer), winner: nil)]))[.player1]!.contains(.fullHouse))
    }

    func testCareerBadges() {
        func history(_ wins: [Bool], points: Int = 30) -> [BadgeEngine.CareerMatch] {
            wins.enumerated().map { .init(matchId: UUID(), date: Date(timeIntervalSince1970: TimeInterval($0.offset)), won: $0.element, pointsWon: points) }
        }
        let first = history([false, true, true, true])
        XCTAssertEqual(engine.careerBadges(in: first[1].matchId, history: first, earnedElsewhere: []), [.offTheMark])
        XCTAssertEqual(engine.careerBadges(in: first[3].matchId, history: first, earnedElsewhere: []), [.hatTrick, .centurion],
                       "third win in a row; 4 × 30 points crosses 100")
        XCTAssertEqual(engine.careerBadges(in: first[3].matchId, history: first, earnedElsewhere: [.centurion]), [.hatTrick])

        let ten = history(Array(repeating: true, count: 10), points: 0)
        XCTAssertTrue(engine.careerBadges(in: ten[9].matchId, history: ten, earnedElsewhere: []).contains(.tenOutOfTen))
        XCTAssertFalse(engine.careerBadges(in: ten[8].matchId, history: ten, earnedElsewhere: []).contains(.tenOutOfTen))
    }

    // MARK: - Set 05 / 06

    func testPerfectTenAndUnbreakable() {
        let earned = engine.badges(for: input([game([(.player1, 11)])]))
        XCTAssertTrue(earned[.player1]!.isSuperset(of: [.perfectTen, .unbreakable]))
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

        let firstLong = [BadgeRally(winner: .player1, duration: 90), BadgeRally(winner: .player2, duration: 70)]
        XCTAssertNil(engine.badges(for: input([BadgeGame(rallies: firstLong, winner: nil)]))[.player1], "first rally never counts")
        XCTAssertNil(engine.badges(for: input([BadgeGame(rallies: firstLong, winner: nil)]))[.player2], "70 s is short of 75")
        let secondLong = [BadgeRally(winner: .player2, duration: 5), BadgeRally(winner: .player1, duration: 75)]
        XCTAssertEqual(engine.badges(for: input([BadgeGame(rallies: secondLong, winner: nil)]))[.player1], [.endurance])
    }

    func testPhotoFinishAndIronMan() {
        var match = input([closeGame(.player1), closeGame(.player2), closeGame(.player1), closeGame(.player2), closeGame(.player1)], winner: .player1)
        XCTAssertTrue(engine.badges(for: match)[.player1]!.contains(.photoFinish))
        XCTAssertFalse(engine.badges(for: match)[.player1]!.contains(.ironMan))
        match.duration = 61 * 60
        XCTAssertTrue(engine.badges(for: match)[.player1]!.contains(.ironMan))
        XCTAssertTrue(engine.badges(for: match)[.player2]!.contains(.ironMan), "both played it out")
    }

    func testNemesisAndVeteran() {
        let kristian = (0..<5).map { BadgeEngine.CareerMatch(matchId: UUID(), date: Date(timeIntervalSince1970: TimeInterval($0)), won: true, pointsWon: 0, opponentKey: "kristian") }
        XCTAssertTrue(engine.careerBadges(in: kristian[4].matchId, history: kristian, earnedElsewhere: []).contains(.nemesis))
        XCTAssertFalse(engine.careerBadges(in: kristian[3].matchId, history: kristian, earnedElsewhere: []).contains(.nemesis))

        let many = (0..<25).map { BadgeEngine.CareerMatch(matchId: UUID(), date: Date(timeIntervalSince1970: TimeInterval($0)), won: false, pointsWon: 0, opponentKey: "x\($0)") }
        XCTAssertEqual(engine.careerBadges(in: many[24].matchId, history: many, earnedElsewhere: []), [.veteran])
    }
}
