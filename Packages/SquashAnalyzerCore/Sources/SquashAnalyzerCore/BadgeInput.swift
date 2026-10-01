import Foundation

public extension Match {
    var badgeInput: BadgeMatchInput {
        BadgeMatchInput(
            games: games.map { game in
                BadgeGame(rallies: game.points.map { point in
                              BadgeRally(winner: point.scorer, shot: point.shotType, pointType: point.pointType, zone: point.zone,
                                         duration: point.duration, isVolley: point.isVolley)
                          },
                          winner: game.winner)
            },
            player1GamesBefore: player1GamesBefore,
            player2GamesBefore: player2GamesBefore,
            player1GamesWon: player1GamesWon,
            player2GamesWon: player2GamesWon,
            matchWinner: matchWinner,
            gamesToWin: gamesToWin,
            recordsPointTypes: true,
            duration: totalMatchDuration()
        )
    }

    /// Rally winners in play order across the tracked games
    var rallyWinners: [Player] {
        games.flatMap { game in game.points.map { point in point.scorer } }
    }
}

public extension RefereeMatch {
    var badgeInput: BadgeMatchInput {
        func rallies(_ entries: [RefereePointEntry]) -> [BadgeRally] {
            entries.map { entry in BadgeRally(winner: entry.scorer, pointType: entry.isStroke ? .stroke : nil) }
        }
        var games = completedGames.map { game in BadgeGame(rallies: rallies(game.points), winner: game.winner) }
        if !pointHistory.isEmpty {
            games.append(BadgeGame(rallies: rallies(pointHistory), winner: ScoringEngine().winner(for: SquashScore(player1: player1Score, player2: player2Score))))
        }
        return BadgeMatchInput(
            games: games,
            player1GamesBefore: player1GamesBefore,
            player2GamesBefore: player2GamesBefore,
            player1GamesWon: player1TotalGames,
            player2GamesWon: player2TotalGames,
            matchWinner: matchWinner,
            gamesToWin: gamesToWin,
            duration: matchDuration
        )
    }

    /// Rally winners in play order: completed games, then the game on the board
    var rallyWinners: [Player] {
        completedGames.flatMap { game in game.points.map { point in point.scorer } } + pointHistory.map { point in point.scorer }
    }
}
