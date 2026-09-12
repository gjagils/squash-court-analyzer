import Foundation

/// Pure squash scoring rules. Keeping these rules out of SwiftUI and SwiftData
/// makes them deterministic and easy to unit test.
struct SquashScore: Equatable {
    var player1: Int = 0
    var player2: Int = 0
}

struct ScoringEngine {
    func score(afterPointFor player: Player, from score: SquashScore) -> SquashScore {
        var result = score
        if player == .player1 {
            result.player1 += 1
        } else {
            result.player2 += 1
        }
        return result
    }

    func isGameOver(_ score: SquashScore) -> Bool {
        let high = max(score.player1, score.player2)
        let low = min(score.player1, score.player2)
        return high >= 11 && high - low >= 2
    }

    func winner(for score: SquashScore) -> Player? {
        guard isGameOver(score) else { return nil }
        return score.player1 > score.player2 ? .player1 : .player2
    }
}
