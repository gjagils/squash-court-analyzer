import Foundation
import Observation

/// A single undo-able action during a referee game.
private enum RefereeAction {
    case point(prevServer: Player, prevSide: ServerSide, prevP1Score: Int, prevP2Score: Int, prevLastPointAt: Date?)
    case sideOverride(prevSide: ServerSide, prevPreferredSide: ServerSide?)
}

/// One rally won, as shown in the scoring timeline between the two players.
public struct RefereePointEntry: Identifiable, Equatable {
    public let id: UUID
    public let scorer: Player
    public let score: Int
    public var side: ServerSide
    public let isStroke: Bool

    public init(id: UUID = UUID(), scorer: Player, score: Int, side: ServerSide, isStroke: Bool) {
        self.id = id
        self.scorer = scorer
        self.score = score
        self.side = side
        self.isStroke = isStroke
    }

    public var label: String { "\(score)\(side.shortCode)" }
}

/// Completed game result.
public struct CompletedRefereeGame: Identifiable {
    public let id: UUID
    public let number: Int
    public let player1Score: Int
    public let player2Score: Int
    public let winner: Player
    public var duration: TimeInterval?
    public var points: [RefereePointEntry]

    public init(id: UUID = UUID(), number: Int, player1Score: Int, player2Score: Int, winner: Player, duration: TimeInterval? = nil, points: [RefereePointEntry] = []) {
        self.id = id
        self.number = number
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.winner = winner
        self.duration = duration
        self.points = points
    }
}

/// One game as it appears in share texts: completed games plus the game on the board.
public struct RefereeGameSummary {
    public let number: Int
    public let player1Score: Int
    public let player2Score: Int
    public let winner: Player?
    public let duration: TimeInterval?
    public let points: [RefereePointEntry]

    public init(number: Int, player1Score: Int, player2Score: Int, winner: Player?, duration: TimeInterval?, points: [RefereePointEntry]) {
        self.number = number
        self.player1Score = player1Score
        self.player2Score = player2Score
        self.winner = winner
        self.duration = duration
        self.points = points
    }

    public var rallies: Int { player1Score + player2Score }
    public var strokes: Int { points.filter(\.isStroke).count }

    public var longestRun: (player: Player, length: Int)? {
        var best: (Player, Int)? = nil
        var current: (Player, Int)? = nil
        for entry in points {
            if let c = current, c.0 == entry.scorer {
                current = (c.0, c.1 + 1)
            } else {
                current = (entry.scorer, 1)
            }
            if let c = current, c.1 > (best?.1 ?? 0) { best = c }
        }
        return best.map { (player: $0.0, length: $0.1) }
    }
}

/// Live referee match state.
@Observable
public class RefereeMatch: Identifiable {
    public let id: UUID
    public var player1Name: String
    public var player2Name: String
    public var player1Id: UUID?
    public var player2Id: UUID?
    public var bestOf: Int
    public let player1GamesBefore: Int
    public let player2GamesBefore: Int
    public var player1Score: Int = 0
    public var player2Score: Int = 0
    public var currentServer: Player
    public var serverSide: ServerSide = .right
    public var currentGameNumber: Int = 1
    public var completedGames: [CompletedRefereeGame] = []
    public var pointHistory: [RefereePointEntry] = []
    public var player1PreferredSide: ServerSide?
    public var player2PreferredSide: ServerSide?
    public var lastCallText: String?
    public let matchStartedAt: Date
    public var gameStartedAt: Date
    public var lastPointAt: Date?

    private var undoStack: [RefereeAction] = []

    public init(id: UUID = UUID(), player1Name: String, player2Name: String, bestOf: Int, startingServer: Player,
                player1GamesBefore: Int = 0, player2GamesBefore: Int = 0, matchStartedAt: Date = Date()) {
        self.id = id
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.bestOf = bestOf
        let validHeadStart = Match.isValidHeadStart(player1: player1GamesBefore, player2: player2GamesBefore, bestOf: bestOf)
        self.player1GamesBefore = validHeadStart ? player1GamesBefore : 0
        self.player2GamesBefore = validHeadStart ? player2GamesBefore : 0
        self.currentGameNumber = 1 + self.player1GamesBefore + self.player2GamesBefore
        self.currentServer = startingServer
        self.matchStartedAt = matchStartedAt
        self.gameStartedAt = Date()
    }

    public var player1GamesWon: Int { player1GamesBefore + completedGames.filter { $0.winner == .player1 }.count }
    public var player2GamesWon: Int { player2GamesBefore + completedGames.filter { $0.winner == .player2 }.count }
    public var gamesToWin: Int { (bestOf / 2) + 1 }
    public var firstGameNumber: Int { 1 + player1GamesBefore + player2GamesBefore }
    public var player1TotalGames: Int { player1GamesWon + (currentGameWinner == .player1 ? 1 : 0) }
    public var player2TotalGames: Int { player2GamesWon + (currentGameWinner == .player2 ? 1 : 0) }
    public var isMatchOver: Bool { player1TotalGames >= gamesToWin || player2TotalGames >= gamesToWin }
    public var matchWinner: Player? {
        guard isMatchOver else { return nil }
        return player1TotalGames > player2TotalGames ? .player1 : .player2
    }
    public var allGameResults: [(number: Int, p1: Int, p2: Int, winner: Player)] {
        let done = completedGames.map { (number: $0.number, p1: $0.player1Score, p2: $0.player2Score, winner: $0.winner) }
        if let w = currentGameWinner { return done + [(number: currentGameNumber, p1: player1Score, p2: player2Score, winner: w)] }
        return done
    }
    private var currentScore: SquashScore { SquashScore(player1: player1Score, player2: player2Score) }
    public var isGameOver: Bool { ScoringEngine().isGameOver(currentScore) }
    public var currentGameWinner: Player? { ScoringEngine().winner(for: currentScore) }
    public var canUndo: Bool { !undoStack.isEmpty }

    public func name(for player: Player) -> String { player == .player1 ? player1Name : player2Name }
    public func preferredSide(for player: Player) -> ServerSide? { player == .player1 ? player1PreferredSide : player2PreferredSide }
    private func handOutSide(for player: Player) -> ServerSide { preferredSide(for: player) ?? .right }

    public func awardPoint(to scorer: Player, isStroke: Bool = false) {
        guard !isGameOver else { return }
        undoStack.append(.point(prevServer: currentServer, prevSide: serverSide, prevP1Score: player1Score, prevP2Score: player2Score, prevLastPointAt: lastPointAt))
        if scorer == .player1 { player1Score += 1 } else { player2Score += 1 }
        lastPointAt = Date()
        if scorer == currentServer {
            serverSide = serverSide.opposite
        } else {
            currentServer = scorer
            serverSide = handOutSide(for: scorer)
        }
        let scorerScore = scorer == .player1 ? player1Score : player2Score
        pointHistory.append(RefereePointEntry(scorer: scorer, score: scorerScore, side: serverSide, isStroke: isStroke))
        lastCallText = nil
    }

    public func overrideSide(to side: ServerSide) {
        guard !isGameOver, side != serverSide else { return }
        undoStack.append(.sideOverride(prevSide: serverSide, prevPreferredSide: preferredSide(for: currentServer)))
        serverSide = side
        setPreferredSide(side, for: currentServer)
        if let last = pointHistory.last, last.scorer == currentServer {
            pointHistory[pointHistory.count - 1].side = side
        }
    }

    private func setPreferredSide(_ side: ServerSide?, for player: Player) {
        if player == .player1 { player1PreferredSide = side } else { player2PreferredSide = side }
    }

    public func callLet() { lastCallText = "LET" }

    public func clearCallText() { lastCallText = nil }

    public func callStroke(to player: Player) {
        lastCallText = "STROKE -> \(name(for: player).uppercased())"
        awardPoint(to: player, isStroke: true)
    }

    public func undo() {
        guard let action = undoStack.popLast() else { return }
        switch action {
        case .point(let prevServer, let prevSide, let prevP1, let prevP2, let prevLastPointAt):
            player1Score = prevP1
            player2Score = prevP2
            currentServer = prevServer
            serverSide = prevSide
            lastPointAt = prevLastPointAt
            _ = pointHistory.popLast()
        case .sideOverride(let prevSide, let prevPreferredSide):
            serverSide = prevSide
            setPreferredSide(prevPreferredSide, for: currentServer)
            if let last = pointHistory.last, last.scorer == currentServer {
                pointHistory[pointHistory.count - 1].side = prevSide
            }
        }
        lastCallText = nil
    }

    public func confirmNextGame() {
        guard let winner = currentGameWinner else { return }
        completedGames.append(CompletedRefereeGame(number: currentGameNumber, player1Score: player1Score, player2Score: player2Score, winner: winner, duration: currentGameDuration, points: pointHistory))
        currentGameNumber += 1
        player1Score = 0
        player2Score = 0
        pointHistory.removeAll()
        undoStack.removeAll()
        lastCallText = nil
        gameStartedAt = Date()
        lastPointAt = nil
        currentServer = winner
        serverSide = handOutSide(for: winner)
    }

    public var currentGameDuration: TimeInterval {
        let end = isGameOver ? (lastPointAt ?? Date()) : Date()
        return max(0.0, end.timeIntervalSince(gameStartedAt))
    }

    public var matchDuration: TimeInterval {
        let end = isMatchOver ? (lastPointAt ?? Date()) : Date()
        return max(0.0, end.timeIntervalSince(matchStartedAt))
    }

    public var gameSummaries: [RefereeGameSummary] {
        var games = completedGames.map {
            RefereeGameSummary(number: $0.number, player1Score: $0.player1Score, player2Score: $0.player2Score, winner: $0.winner, duration: $0.duration, points: $0.points)
        }
        if player1Score > 0 || player2Score > 0 {
            games.append(RefereeGameSummary(number: currentGameNumber, player1Score: player1Score, player2Score: player2Score, winner: currentGameWinner, duration: currentGameDuration, points: pointHistory))
        }
        return games
    }

    public var totalRallies: Int { gameSummaries.reduce(0) { $0 + $1.rallies } }
    public var totalStrokes: Int { gameSummaries.reduce(0) { $0 + $1.strokes } }
    public var longestRun: (player: Player, length: Int)? {
        gameSummaries.compactMap(\.longestRun).max { $0.length < $1.length }
    }

    public var whatsAppText: String { shareText(style: .compact) }
    public func shareText(style: MatchShareStyle) -> String { shareReport.text(style: style) }
    public var shareReport: MatchShareReport {
        MatchShareReport(
            player1Name: player1Name,
            player2Name: player2Name,
            bestOf: bestOf,
            firstGameNumber: firstGameNumber,
            player1Games: player1TotalGames,
            player2Games: player2TotalGames,
            matchWinner: matchWinner,
            games: gameSummaries.map {
                MatchShareReport.Game(number: $0.number, player1Score: $0.player1Score, player2Score: $0.player2Score, winner: $0.winner, duration: $0.duration, rallyWinners: $0.points.map(\.scorer), strokes: $0.strokes)
            },
            startedAt: matchStartedAt,
            duration: matchDuration
        )
    }
}
