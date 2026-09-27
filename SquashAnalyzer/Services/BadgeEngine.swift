import Foundation
import SquashAnalyzerCore

extension Match {
    var badgeInput: BadgeMatchInput {
        BadgeMatchInput(
            games: games.map { game in
                BadgeGame(rallies: game.points.map {
                              BadgeRally(winner: $0.scorer, shot: $0.shotType, pointType: $0.pointType, zone: $0.zone, duration: $0.duration)
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
        games.flatMap { $0.points.map(\.scorer) }
    }
}

extension RefereeMatch {
    var badgeInput: BadgeMatchInput {
        func rallies(_ entries: [RefereePointEntry]) -> [BadgeRally] {
            entries.map { BadgeRally(winner: $0.scorer, pointType: $0.isStroke ? .stroke : nil) }
        }
        var games = completedGames.map { BadgeGame(rallies: rallies($0.points), winner: $0.winner) }
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
        completedGames.flatMap { $0.points.map(\.scorer) } + pointHistory.map(\.scorer)
    }
}
