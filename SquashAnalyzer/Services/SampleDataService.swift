import Foundation
import SwiftData

/// Generates realistic sample match data for testing and demonstration
enum SampleDataService {

    static func createSampleMatch(context: ModelContext) {
        let savedMatch = SavedMatch(
            player1Name: "Niels",
            player2Name: "Paul",
            matchStartingServer: .player1,
            bestOf: 5,
            savedAt: Date().addingTimeInterval(-3600)
        )
        context.insert(savedMatch)

        // Game 1: Niels wint 11-7
        let game1 = makeSavedGame(
            number: 1,
            p1Name: "Niels", p2Name: "Paul",
            p1Score: 11, p2Score: 7,
            winner: .player1,
            server: .player1,
            savedAt: Date().addingTimeInterval(-3600),
            context: context,
            points: samplePoints1()
        )
        game1.match = savedMatch
        savedMatch.games.append(game1)

        // Game 2: Paul wint 11-9
        let game2 = makeSavedGame(
            number: 2,
            p1Name: "Niels", p2Name: "Paul",
            p1Score: 9, p2Score: 11,
            winner: .player2,
            server: .player2,
            savedAt: Date().addingTimeInterval(-2400),
            context: context,
            points: samplePoints2()
        )
        game2.match = savedMatch
        savedMatch.games.append(game2)

        // Game 3: Niels wint 11-8
        let game3 = makeSavedGame(
            number: 3,
            p1Name: "Niels", p2Name: "Paul",
            p1Score: 11, p2Score: 8,
            winner: .player1,
            server: .player1,
            savedAt: Date().addingTimeInterval(-1200),
            context: context,
            points: samplePoints3()
        )
        game3.match = savedMatch
        savedMatch.games.append(game3)

        try? context.save()
    }

    // MARK: - Game Factory

    private static func makeSavedGame(
        number: Int,
        p1Name: String, p2Name: String,
        p1Score: Int, p2Score: Int,
        winner: Player,
        server: Player,
        savedAt: Date,
        context: ModelContext,
        points: [(scorer: Player, type: PointType, zone: CourtZone?, shot: ShotType?, server: Player, p1: Int, p2: Int)]
    ) -> SavedGame {
        let game = SavedGame(
            gameNumber: number,
            player1Name: p1Name,
            player2Name: p2Name,
            player1Score: p1Score,
            player2Score: p2Score,
            startingServer: server,
            winner: winner
        )
        game.savedAt = savedAt
        context.insert(game)

        for (i, pt) in points.enumerated() {
            let sp = SavedPoint(
                pointNumber: i + 1,
                scorer: pt.scorer,
                pointType: pt.type,
                zone: pt.zone,
                shotType: pt.shot,
                server: pt.server,
                player1Score: pt.p1,
                player2Score: pt.p2,
                duration: Double.random(in: 3...20)
            )
            sp.game = game
            game.points.append(sp)
            context.insert(sp)
        }

        return game
    }

    // MARK: - Sample Point Sequences

    private static func samplePoints1() -> [(scorer: Player, type: PointType, zone: CourtZone?, shot: ShotType?, server: Player, p1: Int, p2: Int)] {
        [
            (.player1, .winner, .frontLeft, .drop, .player1, 1, 0),
            (.player2, .unforcedError, nil, nil, .player2, 1, 1),
            (.player1, .forcedError, .backRight, .drive, .player1, 2, 1),
            (.player1, .winner, .frontRight, .drop, .player1, 3, 1),
            (.player2, .winner, .backLeft, .cross, .player2, 3, 2),
            (.player1, .unforcedError, nil, nil, .player1, 3, 3),
            (.player1, .winner, .frontMiddle, .volley, .player1, 4, 3),
            (.player1, .forcedError, .middleLeft, .drive, .player1, 5, 3),
            (.player2, .winner, .frontLeft, .drop, .player2, 5, 4),
            (.player1, .winner, .backRight, .cross, .player1, 6, 4),
            (.player2, .unforcedError, nil, nil, .player2, 6, 5),
            (.player1, .winner, .frontLeft, .drop, .player1, 7, 5),
            (.player2, .winner, .middleRight, .boast, .player2, 7, 6),
            (.player1, .forcedError, .backLeft, .drive, .player1, 8, 6),
            (.player1, .winner, .frontRight, .drop, .player1, 9, 6),
            (.player2, .unforcedError, nil, nil, .player2, 9, 7),
            (.player1, .winner, .middleMiddle, .drive, .player1, 10, 7),
            (.player1, .forcedError, .backRight, .cross, .player1, 11, 7),
        ]
    }

    private static func samplePoints2() -> [(scorer: Player, type: PointType, zone: CourtZone?, shot: ShotType?, server: Player, p1: Int, p2: Int)] {
        [
            (.player2, .winner, .frontLeft, .drop, .player2, 0, 1),
            (.player1, .winner, .backRight, .drive, .player1, 1, 1),
            (.player2, .forcedError, .middleLeft, .cross, .player2, 1, 2),
            (.player1, .unforcedError, nil, nil, .player1, 1, 3),
            (.player2, .winner, .frontRight, .drop, .player2, 1, 4),
            (.player1, .winner, .backLeft, .boast, .player1, 2, 4),
            (.player2, .unforcedError, nil, nil, .player2, 2, 5),
            (.player1, .winner, .frontLeft, .volley, .player1, 3, 5),
            (.player2, .forcedError, .backRight, .drive, .player2, 3, 6),
            (.player1, .unforcedError, nil, nil, .player1, 3, 7),
            (.player2, .winner, .frontLeft, .drop, .player2, 3, 8),
            (.player1, .winner, .middleRight, .drive, .player1, 4, 8),
            (.player2, .winner, .frontRight, .drop, .player2, 4, 9),
            (.player1, .winner, .backLeft, .cross, .player1, 5, 9),
            (.player2, .unforcedError, nil, nil, .player2, 5, 10),
            (.player1, .unforcedError, nil, nil, .player1, 5, 11),
            (.player2, .winner, .frontLeft, .drop, .player2, 6, 11),
            (.player1, .winner, .backRight, .drive, .player1, 7, 11),
            (.player2, .forcedError, .middleLeft, .cross, .player2, 7, 12),
            (.player1, .unforcedError, nil, nil, .player1, 7, 13),
        ]
    }

    private static func samplePoints3() -> [(scorer: Player, type: PointType, zone: CourtZone?, shot: ShotType?, server: Player, p1: Int, p2: Int)] {
        [
            (.player1, .winner, .frontLeft, .drop, .player1, 1, 0),
            (.player1, .forcedError, .backRight, .drive, .player1, 2, 0),
            (.player2, .winner, .frontRight, .drop, .player2, 2, 1),
            (.player1, .winner, .middleLeft, .cross, .player1, 3, 1),
            (.player2, .unforcedError, nil, nil, .player2, 3, 2),
            (.player1, .winner, .frontLeft, .drop, .player1, 4, 2),
            (.player2, .winner, .backRight, .boast, .player2, 4, 3),
            (.player1, .unforcedError, nil, nil, .player1, 4, 4),
            (.player1, .winner, .frontMiddle, .volley, .player1, 5, 4),
            (.player1, .forcedError, .backLeft, .drive, .player1, 6, 4),
            (.player2, .winner, .frontLeft, .drop, .player2, 6, 5),
            (.player1, .winner, .middleRight, .cross, .player1, 7, 5),
            (.player2, .unforcedError, nil, nil, .player2, 7, 6),
            (.player1, .winner, .frontRight, .drop, .player1, 8, 6),
            (.player2, .winner, .backLeft, .drive, .player2, 8, 7),
            (.player1, .winner, .frontLeft, .drop, .player1, 9, 7),
            (.player2, .unforcedError, nil, nil, .player2, 9, 8),
            (.player1, .winner, .middleMiddle, .drive, .player1, 10, 8),
            (.player1, .winner, .frontRight, .drop, .player1, 11, 8),
        ]
    }
}
