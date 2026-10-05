import Foundation

public extension Match {
    var badgeInput: BadgeMatchInput {
        BadgeMatchInput(
            games: games.map { game in
                BadgeGame(rallies: game.points.map { point in
                              BadgeRally(winner: point.scorer, shot: point.shotType, pointType: point.pointType, zone: point.zone,
                                         duration: point.isTimed ? point.duration : nil, isVolley: point.isVolley, server: point.server)
                          },
                          winner: game.winner,
                          duration: Match.badgeGameDuration(game))
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

    /// The game's playing time as the rally clock saw it (the sum of its rally
    /// times, like `totalMatchDuration`); nil for a game that was not timed
    static func badgeGameDuration(_ game: Game) -> TimeInterval? {
        var seconds = 0.0
        for point in game.points {
            seconds += point.duration
        }
        return seconds > 0.0 ? seconds : nil
    }

    /// Rally winners in play order across the tracked games
    var rallyWinners: [Player] {
        games.flatMap { game in game.points.map { point in point.scorer } }
    }
}

public extension RefereeMatch {
    var badgeInput: BadgeMatchInput {
        // Referee mode does not store who served; within a game the winner of a
        // rally serves the next, so only the first rally's server is unknown
        func rallies(_ entries: [RefereePointEntry]) -> [BadgeRally] {
            var list: [BadgeRally] = []
            var server: Player? = nil
            for entry in entries {
                list.append(BadgeRally(winner: entry.scorer, pointType: entry.isStroke ? .stroke : nil, server: server))
                server = entry.scorer
            }
            return list
        }
        var games = completedGames.map { game in BadgeGame(rallies: rallies(game.points), winner: game.winner, duration: game.duration) }
        if !pointHistory.isEmpty {
            let winner = ScoringEngine().winner(for: SquashScore(player1: player1Score, player2: player2Score))
            var duration: TimeInterval? = nil
            if winner != nil { duration = currentGameDuration }
            games.append(BadgeGame(rallies: rallies(pointHistory), winner: winner, duration: duration))
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
