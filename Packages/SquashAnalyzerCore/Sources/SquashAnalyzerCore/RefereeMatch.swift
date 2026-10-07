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
    /// Moved forward when a stopped match is resumed (`skipClosedTime`)
    public var matchStartedAt: Date
    public var gameStartedAt: Date
    public var lastPointAt: Date?

    private var undoStack: [RefereeAction] = []
    /// Who served the first rally of this game, and from which box. Kept with
    /// a saved match so undo can be rebuilt after resuming (`rebuildUndo`).
    public var openingServer: Player?
    public var openingSide: ServerSide?
    /// The clock for rallies and games; tests set a fixed one to assert durations exactly
    public var now: () -> Date = { Date() }

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
        // The first game starts with the match: one injectable moment, not a second Date()
        self.gameStartedAt = matchStartedAt
    }

    public var player1GamesWon: Int { player1GamesBefore + completedGames.filter { $0.winner == .player1 }.count }
    public var player2GamesWon: Int { player2GamesBefore + completedGames.filter { $0.winner == .player2 }.count }
    public var gamesToWin: Int { MatchStand.gamesToWin(bestOf: bestOf) }
    public var firstGameNumber: Int { 1 + player1GamesBefore + player2GamesBefore }
    public var player1TotalGames: Int { player1GamesWon + (currentGameWinner == .player1 ? 1 : 0) }
    public var player2TotalGames: Int { player2GamesWon + (currentGameWinner == .player2 ? 1 : 0) }
    private var stand: MatchStand { MatchStand(bestOf: bestOf, player1Games: player1TotalGames, player2Games: player2TotalGames) }
    public var isMatchOver: Bool { stand.isOver }
    public var matchWinner: Player? { stand.winner }
    /// Every finished game, the one still on the board included
    public var allGameResults: [CompletedRefereeGame] {
        var results = completedGames
        if let winner = currentGameWinner {
            results.append(CompletedRefereeGame(number: currentGameNumber, player1Score: player1Score,
                                                player2Score: player2Score, winner: winner))
        }
        return results
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
        if pointHistory.isEmpty {
            openingServer = currentServer
            openingSide = serverSide
        }
        undoStack.append(.point(prevServer: currentServer, prevSide: serverSide, prevP1Score: player1Score, prevP2Score: player2Score, prevLastPointAt: lastPointAt))
        if scorer == .player1 { player1Score += 1 } else { player2Score += 1 }
        lastPointAt = now()
        let next = ScoringEngine().service(afterRallyWonBy: scorer, from: ServiceState(server: currentServer, side: serverSide),
                                           handOutSide: handOutSide(for: scorer))
        currentServer = next.server
        serverSide = next.side
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

    /// After the point: `awardPoint` clears the banner, so setting it first lost it
    public func callStroke(to player: Player) {
        awardPoint(to: player, isStroke: true)
        lastCallText = "STROKE -> \(name(for: player).uppercased())"
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

    /// After resuming a saved match: undo again works for every rally of the
    /// current game. Each rally's server and box follow from the rally before
    /// it (box changes are in the timeline), the first from `openingServer`.
    public func rebuildUndo() {
        undoStack.removeAll()
        guard let firstServer = openingServer, let firstSide = openingSide else { return }
        var server: Player = firstServer
        var side: ServerSide = firstSide
        var score1 = 0
        var score2 = 0
        // The rallies have no time of their own: before the first there was no
        // point (nil, exact); later ones get the saved time of the last point,
        // so the rally clock after an undo does not jump back to the game start
        let savedLastPointAt = lastPointAt
        for (index, entry) in pointHistory.enumerated() {
            let previousTime: Date? = index == 0 ? nil : savedLastPointAt
            undoStack.append(.point(prevServer: server, prevSide: side, prevP1Score: score1, prevP2Score: score2, prevLastPointAt: previousTime))
            if entry.scorer == Player.player1 { score1 += 1 } else { score2 += 1 }
            server = entry.scorer
            side = entry.side
        }
    }

    public func confirmNextGame() {
        guard let winner = currentGameWinner else { return }
        completedGames.append(CompletedRefereeGame(number: currentGameNumber, player1Score: player1Score, player2Score: player2Score, winner: winner, duration: currentGameDuration, points: pointHistory))
        currentGameNumber += 1
        player1Score = 0
        player2Score = 0
        pointHistory.removeAll()
        undoStack.removeAll()
        openingServer = nil
        openingSide = nil
        lastCallText = nil
        gameStartedAt = now()
        lastPointAt = nil
        currentServer = winner
        serverSide = handOutSide(for: winner)
    }

    public var currentGameDuration: TimeInterval {
        let end = isGameOver ? (lastPointAt ?? now()) : now()
        return max(0.0, end.timeIntervalSince(gameStartedAt))
    }

    /// Resuming a match that was saved at `stoppedAt`: the match and game
    /// clocks skip the time the app was closed and continue where they were,
    /// instead of showing 970 minutes the next day.
    public func skipClosedTime(since stoppedAt: Date) {
        let away = now().timeIntervalSince(stoppedAt)
        guard away > 0.0, !isMatchOver else { return }
        matchStartedAt = matchStartedAt.addingTimeInterval(away)
        gameStartedAt = gameStartedAt.addingTimeInterval(away)
    }

    public var matchDuration: TimeInterval {
        let end = isMatchOver ? (lastPointAt ?? now()) : now()
        return max(0.0, end.timeIntervalSince(matchStartedAt))
    }

    /// The games as the share texts see them: completed ones plus the game on
    /// the board once a rally has been played there
    public var gameSummaries: [MatchShareReport.Game] {
        var games: [MatchShareReport.Game] = []
        for game in completedGames {
            games.append(RefereeMatch.shareGame(number: game.number, player1Score: game.player1Score, player2Score: game.player2Score,
                                                winner: game.winner, duration: game.duration, points: game.points))
        }
        if player1Score > 0 || player2Score > 0 {
            games.append(RefereeMatch.shareGame(number: currentGameNumber, player1Score: player1Score, player2Score: player2Score,
                                                winner: currentGameWinner, duration: currentGameDuration, points: pointHistory))
        }
        return games
    }

    private static func shareGame(number: Int, player1Score: Int, player2Score: Int, winner: Player?,
                                  duration: TimeInterval?, points: [RefereePointEntry]) -> MatchShareReport.Game {
        var winners: [Player] = []
        var strokes = 0
        for point in points {
            winners.append(point.scorer)
            if point.isStroke { strokes += 1 }
        }
        return MatchShareReport.Game(number: number, player1Score: player1Score, player2Score: player2Score, winner: winner,
                                     duration: duration, rallyWinners: winners, strokes: strokes)
    }

    public var totalRallies: Int { gameSummaries.reduce(0) { $0 + $1.rallies } }
    public var totalStrokes: Int { gameSummaries.reduce(0) { $0 + $1.strokes } }
    public var longestRun: PlayerRun? { shareReport.longestRun }

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
            games: gameSummaries,
            startedAt: matchStartedAt,
            duration: matchDuration
        )
    }
}
