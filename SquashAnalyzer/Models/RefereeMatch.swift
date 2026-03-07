import Foundation
import Observation

/// Server side (left or right service box)
enum ServerSide: String {
    case left = "Links"
    case right = "Rechts"

    var icon: String {
        self == .left ? "arrow.left" : "arrow.right"
    }
}

/// A single undo-able action during a referee game
private enum RefereeAction {
    case point(scorer: Player, prevServer: Player, prevSide: ServerSide, prevP1Score: Int, prevP2Score: Int, prevP1PreferredSide: ServerSide?, prevP2PreferredSide: ServerSide?)
}

/// Completed game result
struct CompletedRefereeGame: Identifiable {
    let id = UUID()
    let number: Int
    let player1Score: Int
    let player2Score: Int
    let winner: Player
}

/// Live referee match state
@Observable
class RefereeMatch {
    var player1Name: String
    var player2Name: String
    var bestOf: Int

    // Current game
    var player1Score: Int = 0
    var player2Score: Int = 0
    var currentServer: Player
    var serverSide: ServerSide = .right
    var currentGameNumber: Int = 1

    // Completed games
    var completedGames: [CompletedRefereeGame] = []

    // Manually overridden service side per player (persists across games in the match)
    var player1PreferredSide: ServerSide? = nil
    var player2PreferredSide: ServerSide? = nil

    // Let / stroke flash
    var lastCallText: String? = nil

    private var undoStack: [RefereeAction] = []

    init(player1Name: String, player2Name: String, bestOf: Int, startingServer: Player) {
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.bestOf = bestOf
        self.currentServer = startingServer
        self.serverSide = .right  // Always start on right (server score = 0 = even)
    }

    // MARK: - Computed

    var player1GamesWon: Int { completedGames.filter { $0.winner == .player1 }.count }
    var player2GamesWon: Int { completedGames.filter { $0.winner == .player2 }.count }
    var gamesToWin: Int { (bestOf / 2) + 1 }

    // Include the current game's result (when isGameOver) so the match-over check is correct
    // even before confirmNextGame() is called.
    private var p1TotalGames: Int { player1GamesWon + (currentGameWinner == .player1 ? 1 : 0) }
    private var p2TotalGames: Int { player2GamesWon + (currentGameWinner == .player2 ? 1 : 0) }

    var isMatchOver: Bool { p1TotalGames >= gamesToWin || p2TotalGames >= gamesToWin }
    var matchWinner: Player? {
        guard isMatchOver else { return nil }
        return p1TotalGames > p2TotalGames ? .player1 : .player2
    }

    /// All game results including the current game (if finished). Used for saving.
    var allGameResults: [(number: Int, p1: Int, p2: Int, winner: Player)] {
        let done = completedGames.map { (number: $0.number, p1: $0.player1Score, p2: $0.player2Score, winner: $0.winner) }
        if let w = currentGameWinner {
            return done + [(number: currentGameNumber, p1: player1Score, p2: player2Score, winner: w)]
        }
        return done
    }

    var isGameOver: Bool {
        let maxScore = max(player1Score, player2Score)
        let minScore = min(player1Score, player2Score)
        return maxScore >= 11 && (maxScore - minScore) >= 2
    }

    var currentGameWinner: Player? {
        guard isGameOver else { return nil }
        return player1Score > player2Score ? .player1 : .player2
    }

    var canUndo: Bool { !undoStack.isEmpty }

    func name(for player: Player) -> String {
        player == .player1 ? player1Name : player2Name
    }

    // MARK: - Actions

    func awardPoint(to scorer: Player) {
        guard !isGameOver else { return }

        undoStack.append(.point(
            scorer: scorer,
            prevServer: currentServer,
            prevSide: serverSide,
            prevP1Score: player1Score,
            prevP2Score: player2Score,
            prevP1PreferredSide: player1PreferredSide,
            prevP2PreferredSide: player2PreferredSide
        ))

        if scorer == .player1 { player1Score += 1 } else { player2Score += 1 }

        // Update server: scorer always becomes/stays server
        currentServer = scorer
        let scorerScore = scorer == .player1 ? player1Score : player2Score
        let autoSide: ServerSide = scorerScore % 2 == 0 ? .right : .left

        // Use player's manually overridden side if set, otherwise use even/odd rule
        let preferredSide = scorer == .player1 ? player1PreferredSide : player2PreferredSide
        serverSide = preferredSide ?? autoSide

        lastCallText = nil
    }

    /// Override the current server's service side and remember it for the rest of the match.
    func overrideSide(to side: ServerSide) {
        guard !isGameOver else { return }
        serverSide = side
        if currentServer == .player1 {
            player1PreferredSide = side
        } else {
            player2PreferredSide = side
        }
    }

    func callLet() {
        lastCallText = "LET"
        // No score change, just show flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.lastCallText == "LET" { self?.lastCallText = nil }
        }
    }

    func callStroke(to player: Player) {
        lastCallText = "STROKE → \(name(for: player).uppercased())"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.lastCallText = nil
        }
        awardPoint(to: player)
    }

    func undo() {
        guard let action = undoStack.popLast() else { return }
        switch action {
        case .point(_, let prevServer, let prevSide, let prevP1, let prevP2, let prevP1Pref, let prevP2Pref):
            player1Score = prevP1
            player2Score = prevP2
            currentServer = prevServer
            serverSide = prevSide
            player1PreferredSide = prevP1Pref
            player2PreferredSide = prevP2Pref
        }
        lastCallText = nil
    }

    func confirmNextGame() {
        guard let winner = currentGameWinner else { return }
        completedGames.append(CompletedRefereeGame(
            number: currentGameNumber,
            player1Score: player1Score,
            player2Score: player2Score,
            winner: winner
        ))
        currentGameNumber += 1
        player1Score = 0
        player2Score = 0
        undoStack.removeAll()
        lastCallText = nil
        // In a best-of-5, the loser serves next game (or winner can choose — simplified: loser serves)
        currentServer = winner.opponent
        serverSide = .right
    }

    // MARK: - Export

    var whatsAppText: String {
        var lines: [String] = []
        lines.append("🏸 Squash score")
        lines.append("\(player1Name) vs \(player2Name)")
        lines.append("")

        for game in completedGames {
            let winnerName = game.winner == .player1 ? player1Name : player2Name
            lines.append("Game \(game.number): \(game.player1Score)-\(game.player2Score) (\(winnerName))")
        }

        // Add current game if still in progress or just finished
        if !completedGames.isEmpty || player1Score > 0 || player2Score > 0 {
            if isGameOver, let winner = currentGameWinner {
                let winnerName = winner == .player1 ? player1Name : player2Name
                lines.append("Game \(currentGameNumber): \(player1Score)-\(player2Score) (\(winnerName))")
            } else if player1Score > 0 || player2Score > 0 {
                lines.append("Bezig game \(currentGameNumber): \(player1Score)-\(player2Score)")
            }
        }

        lines.append("")
        if let winner = matchWinner {
            lines.append("🏆 Winnaar: \(name(for: winner)) (\(player1GamesWon)-\(player2GamesWon))")
        } else {
            lines.append("Stand: \(player1Name) \(player1GamesWon) - \(player2GamesWon) \(player2Name)")
        }

        return lines.joined(separator: "\n")
    }
}
