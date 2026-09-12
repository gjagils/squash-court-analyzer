import Foundation
import Observation

/// Server side (left or right service box)
enum ServerSide: String {
    case left = "Links"
    case right = "Rechts"

    var icon: String {
        self == .left ? "arrow.left" : "arrow.right"
    }

    /// Single-letter code used in the scoring timeline ("4R", "5L")
    var shortCode: String {
        self == .left ? "L" : "R"
    }

    var opposite: ServerSide {
        self == .left ? .right : .left
    }
}

/// A single undo-able action during a referee game
private enum RefereeAction {
    case point(prevServer: Player, prevSide: ServerSide, prevP1Score: Int, prevP2Score: Int)
    case sideOverride(prevSide: ServerSide)
}

/// One rally won, as shown in the scoring timeline between the two players
struct RefereePointEntry: Identifiable, Equatable {
    let id = UUID()
    let scorer: Player
    /// Scorer's score after this rally
    let score: Int
    /// Service box the scorer serves from for the next rally
    var side: ServerSide
    let isStroke: Bool

    var label: String { "\(score)\(side.shortCode)" }
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

    // Rallies won in the current game, oldest first (drives the scoring timeline)
    var pointHistory: [RefereePointEntry] = []

    // Let / stroke flash
    var lastCallText: String? = nil

    private var undoStack: [RefereeAction] = []

    init(player1Name: String, player2Name: String, bestOf: Int, startingServer: Player) {
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.bestOf = bestOf
        self.currentServer = startingServer
        self.serverSide = .right  // First serve of a game defaults to the right box
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

    private var currentScore: SquashScore {
        SquashScore(player1: player1Score, player2: player2Score)
    }

    var isGameOver: Bool { ScoringEngine().isGameOver(currentScore) }

    var currentGameWinner: Player? { ScoringEngine().winner(for: currentScore) }

    var canUndo: Bool { !undoStack.isEmpty }

    func name(for player: Player) -> String {
        player == .player1 ? player1Name : player2Name
    }

    // MARK: - Actions

    func awardPoint(to scorer: Player, isStroke: Bool = false) {
        guard !isGameOver else { return }

        undoStack.append(.point(
            prevServer: currentServer,
            prevSide: serverSide,
            prevP1Score: player1Score,
            prevP2Score: player2Score
        ))

        if scorer == .player1 { player1Score += 1 } else { player2Score += 1 }

        // Service rule: the server who wins a rally keeps serving from the other box.
        // On a hand-out the new server starts from the right box; the referee can
        // correct this with the side chips if the player chooses the left box.
        if scorer == currentServer {
            serverSide = serverSide.opposite
        } else {
            currentServer = scorer
            serverSide = .right
        }

        let scorerScore = scorer == .player1 ? player1Score : player2Score
        pointHistory.append(RefereePointEntry(
            scorer: scorer,
            score: scorerScore,
            side: serverSide,
            isStroke: isStroke
        ))

        lastCallText = nil
    }

    /// Correct the box the current server serves from (e.g. after a hand-out the
    /// player chose the left box). Alternation continues from the corrected box.
    func overrideSide(to side: ServerSide) {
        guard !isGameOver, side != serverSide else { return }
        undoStack.append(.sideOverride(prevSide: serverSide))
        serverSide = side
        if let last = pointHistory.last, last.scorer == currentServer {
            pointHistory[pointHistory.count - 1].side = side
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
        awardPoint(to: player, isStroke: true)
    }

    func undo() {
        guard let action = undoStack.popLast() else { return }
        switch action {
        case .point(let prevServer, let prevSide, let prevP1, let prevP2):
            player1Score = prevP1
            player2Score = prevP2
            currentServer = prevServer
            serverSide = prevSide
            _ = pointHistory.popLast()
        case .sideOverride(let prevSide):
            serverSide = prevSide
            if let last = pointHistory.last, last.scorer == currentServer {
                pointHistory[pointHistory.count - 1].side = prevSide
            }
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
        pointHistory.removeAll()
        undoStack.removeAll()
        lastCallText = nil
        // The winner of the previous game serves first in the next game.
        currentServer = winner
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
