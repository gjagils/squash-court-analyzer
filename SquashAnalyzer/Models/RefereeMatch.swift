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
    case point(prevServer: Player, prevSide: ServerSide, prevP1Score: Int, prevP2Score: Int, prevLastPointAt: Date?)
    case sideOverride(prevSide: ServerSide, prevPreferredSide: ServerSide?)
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
    /// First serve to final rally
    var duration: TimeInterval? = nil
    /// Rally-by-rally history, oldest first (strokes, longest run)
    var points: [RefereePointEntry] = []
}

/// One game as it appears in the share texts: completed games plus the game
/// currently on the board (finished but unconfirmed, or still in progress).
struct RefereeGameSummary {
    let number: Int
    let player1Score: Int
    let player2Score: Int
    /// nil while the game is still in progress
    let winner: Player?
    let duration: TimeInterval?
    let points: [RefereePointEntry]

    var rallies: Int { player1Score + player2Score }
    var strokes: Int { points.filter(\.isStroke).count }

    /// Longest run of consecutive rallies won by one player
    var longestRun: (player: Player, length: Int)? {
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

/// Live referee match state
@Observable
class RefereeMatch {
    var player1Name: String
    var player2Name: String
    var bestOf: Int

    // Games already won when scoring started at game 2 or later ("later instappen")
    let player1GamesBefore: Int
    let player2GamesBefore: Int

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

    // Box a player starts serving from after a hand-out or at the start of a game.
    // Set by tapping Links/Rechts (e.g. a left-hander who always starts left);
    // nil means the default right box. Persists for the whole match.
    var player1PreferredSide: ServerSide? = nil
    var player2PreferredSide: ServerSide? = nil

    // Let / stroke flash
    var lastCallText: String? = nil

    // Timing: game clocks run from the first serve to the final rally
    let matchStartedAt: Date
    var gameStartedAt: Date
    var lastPointAt: Date? = nil

    private var undoStack: [RefereeAction] = []

    init(player1Name: String, player2Name: String, bestOf: Int, startingServer: Player,
         player1GamesBefore: Int = 0, player2GamesBefore: Int = 0) {
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.bestOf = bestOf
        let validHeadStart = Match.isValidHeadStart(player1: player1GamesBefore, player2: player2GamesBefore, bestOf: bestOf)
        self.player1GamesBefore = validHeadStart ? player1GamesBefore : 0
        self.player2GamesBefore = validHeadStart ? player2GamesBefore : 0
        self.currentGameNumber = 1 + self.player1GamesBefore + self.player2GamesBefore
        self.currentServer = startingServer
        self.serverSide = .right  // First serve of a game defaults to the right box
        let now = Date()
        self.matchStartedAt = now
        self.gameStartedAt = now
    }

    // MARK: - Computed

    var player1GamesWon: Int { player1GamesBefore + completedGames.filter { $0.winner == .player1 }.count }
    var player2GamesWon: Int { player2GamesBefore + completedGames.filter { $0.winner == .player2 }.count }
    var gamesToWin: Int { (bestOf / 2) + 1 }

    /// Number of the first scored game (1 unless the match was picked up later)
    var firstGameNumber: Int { 1 + player1GamesBefore + player2GamesBefore }

    /// Games won including the current game once it is finished. The final game of a
    /// match is never confirmed via confirmNextGame(), so the match result must use these.
    var player1TotalGames: Int { player1GamesWon + (currentGameWinner == .player1 ? 1 : 0) }
    var player2TotalGames: Int { player2GamesWon + (currentGameWinner == .player2 ? 1 : 0) }

    var isMatchOver: Bool { player1TotalGames >= gamesToWin || player2TotalGames >= gamesToWin }
    var matchWinner: Player? {
        guard isMatchOver else { return nil }
        return player1TotalGames > player2TotalGames ? .player1 : .player2
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

    func preferredSide(for player: Player) -> ServerSide? {
        player == .player1 ? player1PreferredSide : player2PreferredSide
    }

    /// Box a player serves from when they take over service
    private func handOutSide(for player: Player) -> ServerSide {
        preferredSide(for: player) ?? .right
    }

    // MARK: - Actions

    func awardPoint(to scorer: Player, isStroke: Bool = false) {
        guard !isGameOver else { return }

        undoStack.append(.point(
            prevServer: currentServer,
            prevSide: serverSide,
            prevP1Score: player1Score,
            prevP2Score: player2Score,
            prevLastPointAt: lastPointAt
        ))

        if scorer == .player1 { player1Score += 1 } else { player2Score += 1 }
        lastPointAt = Date()

        // Service rule: the server who wins a rally keeps serving from the other box.
        // On a hand-out the new server starts from their preferred box (right unless
        // the referee tapped Links/Rechts for that player earlier in the match).
        if scorer == currentServer {
            serverSide = serverSide.opposite
        } else {
            currentServer = scorer
            serverSide = handOutSide(for: scorer)
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

    /// Correct the box the current server serves from and remember it as that
    /// player's hand-out box for the rest of the match. Alternation continues
    /// from the corrected box.
    func overrideSide(to side: ServerSide) {
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

    func confirmNextGame() {
        guard let winner = currentGameWinner else { return }
        completedGames.append(CompletedRefereeGame(
            number: currentGameNumber,
            player1Score: player1Score,
            player2Score: player2Score,
            winner: winner,
            duration: currentGameDuration,
            points: pointHistory
        ))
        currentGameNumber += 1
        player1Score = 0
        player2Score = 0
        pointHistory.removeAll()
        undoStack.removeAll()
        lastCallText = nil
        gameStartedAt = Date()
        lastPointAt = nil
        // The winner of the previous game serves first in the next game.
        currentServer = winner
        serverSide = handOutSide(for: winner)
    }

    // MARK: - Timing & summaries

    /// Seconds from the first serve of the current game to its last rally (or now)
    var currentGameDuration: TimeInterval {
        let end = isGameOver ? (lastPointAt ?? Date()) : Date()
        return max(0, end.timeIntervalSince(gameStartedAt))
    }

    /// Whole match, from the first serve to the final rally (or now)
    var matchDuration: TimeInterval {
        let end = isMatchOver ? (lastPointAt ?? Date()) : Date()
        return max(0, end.timeIntervalSince(matchStartedAt))
    }

    /// Completed games plus the game on the board, as long as a rally has been played in it
    var gameSummaries: [RefereeGameSummary] {
        var games = completedGames.map {
            RefereeGameSummary(number: $0.number, player1Score: $0.player1Score, player2Score: $0.player2Score,
                               winner: $0.winner, duration: $0.duration, points: $0.points)
        }
        if player1Score > 0 || player2Score > 0 {
            games.append(RefereeGameSummary(number: currentGameNumber, player1Score: player1Score, player2Score: player2Score,
                                            winner: currentGameWinner, duration: currentGameDuration, points: pointHistory))
        }
        return games
    }

    var totalRallies: Int { gameSummaries.reduce(0) { $0 + $1.rallies } }
    var totalStrokes: Int { gameSummaries.reduce(0) { $0 + $1.strokes } }

    /// Longest run of consecutive rallies won by one player anywhere in the match
    var longestRun: (player: Player, length: Int)? {
        gameSummaries.compactMap(\.longestRun).max { $0.length < $1.length }
    }

    // MARK: - Export

    /// Default WhatsApp text (the short style); the share sheet lets the user pick another
    var whatsAppText: String { shareText(style: .compact) }

    func shareText(style: RefereeShareStyle) -> String {
        switch style {
        case .compact: return compactShareText
        case .scorecard: return scorecardShareText
        case .report: return reportShareText
        }
    }

    // Shared building blocks -------------------------------------------------

    private static let dutch = Locale(identifier: "nl_NL")

    private var shortDateText: String {
        matchStartedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Self.dutch))
    }

    private var longDateText: String {
        matchStartedAt.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(Self.dutch))
    }

    private func minutesText(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes >= 60 { return "\(minutes / 60) u \(String(format: "%02d", minutes % 60)) min" }
        return "\(max(minutes, 1)) min"
    }

    /// "best of 5", with "· vanaf game 3" when scoring started later
    private var bestOfText: String {
        firstGameNumber > 1 ? "best of \(bestOf) · vanaf game \(firstGameNumber)" : "best of \(bestOf)"
    }

    /// "3 – 1" games score, in player order
    private var gamesScoreText: String { "\(player1TotalGames) – \(player2TotalGames)" }

    /// "Jan 3 – 1 Piet" with the winner (or leader) in bold, in player order
    private var namesAndGamesLine: String {
        let p1 = player1TotalGames, p2 = player2TotalGames
        let name1 = p1 > p2 ? "*\(player1Name)*" : player1Name
        let name2 = p2 > p1 ? "*\(player2Name)*" : player2Name
        return "\(name1) \(p1) – \(p2) \(name2)"
    }

    /// Match result or, mid-match, the current stand
    private var resultLine: String {
        if let winner = matchWinner {
            let score = winner == .player1 ? "\(player1TotalGames)–\(player2TotalGames)" : "\(player2TotalGames)–\(player1TotalGames)"
            return "🏆 *\(name(for: winner)) wint met \(score)*"
        }
        if player1TotalGames == player2TotalGames {
            return "Stand: gelijk \(gamesScoreText)"
        }
        let leader: Player = player1TotalGames > player2TotalGames ? .player1 : .player2
        let score = leader == .player1 ? "\(player1TotalGames)–\(player2TotalGames)" : "\(player2TotalGames)–\(player1TotalGames)"
        return "Stand: \(name(for: leader)) leidt met \(score)"
    }

    /// "11-13 · 11-4 · 11-3", an unfinished game shown as "5-3…"
    private var gameScoresInline: String {
        gameSummaries.map { g in
            "\(g.player1Score)-\(g.player2Score)" + (g.winner == nil ? "…" : "")
        }.joined(separator: " · ")
    }

    // 1. Kort ---------------------------------------------------------------

    /// Three lines for a quick group-chat update
    private var compactShareText: String {
        var lines: [String] = []
        lines.append("🏸 *Squash · \(bestOfText)*")
        lines.append((matchWinner != nil ? "🏆 " : "") + namesAndGamesLine)
        if !gameSummaries.isEmpty { lines.append(gameScoresInline) }
        lines.append("⏱ \(minutesText(matchDuration)) · \(shortDateText)")
        return lines.joined(separator: "\n")
    }

    // 2. Scorekaart ---------------------------------------------------------

    /// Monospace score table, one column per game
    private var scorecardShareText: String {
        let games = gameSummaries
        let nameWidth = 10
        func pad(_ s: String, _ w: Int, right: Bool = false) -> String {
            let t = String(s.prefix(w))
            let fill = String(repeating: " ", count: max(0, w - t.count))
            return right ? fill + t : t + fill
        }

        var lines: [String] = []
        lines.append("🏸 *SQUASH SCOREKAART*")
        lines.append("\(shortDateText) · \(bestOfText) · ⏱ \(minutesText(matchDuration))")
        lines.append("")

        if !games.isEmpty {
            var header = pad("", nameWidth)
            var row1 = pad(player1Name, nameWidth)
            var row2 = pad(player2Name, nameWidth)
            for g in games {
                header += pad("G\(g.number)", 4, right: true)
                row1 += pad("\(g.player1Score)", 4, right: true)
                row2 += pad("\(g.player2Score)", 4, right: true)
            }
            lines.append("```")
            lines.append(header)
            lines.append(row1)
            lines.append(row2)
            lines.append("```")
        }

        lines.append(resultLine)
        return lines.joined(separator: "\n")
    }

    // 3. Verslag ------------------------------------------------------------

    /// Game-by-game report with durations and match stats
    private var reportShareText: String {
        var lines: [String] = []
        lines.append("🏸 *SQUASH WEDSTRIJD*")
        lines.append("📅 \(longDateText)")
        lines.append("👥 \(player1Name) – \(player2Name) · \(bestOfText)")
        lines.append("")

        for g in gameSummaries {
            var parts = ["*Game \(g.number)*", "\(g.player1Score)-\(g.player2Score)"]
            if let w = g.winner {
                parts.append("✅ \(name(for: w))")
            } else {
                parts.append("bezig")
            }
            if let d = g.duration { parts.append(minutesText(d)) }
            if g.strokes > 0 { parts.append("\(g.strokes) stroke\(g.strokes == 1 ? "" : "s")") }
            lines.append(parts.joined(separator: " · "))
        }
        if !gameSummaries.isEmpty { lines.append("") }

        lines.append(resultLine)

        var stats = ["⏱ \(minutesText(matchDuration))", "🎾 \(totalRallies) rallies"]
        if totalStrokes > 0 { stats.append("⚡ \(totalStrokes) stroke\(totalStrokes == 1 ? "" : "s")") }
        if let run = longestRun, run.length >= 3 {
            stats.append("🔥 langste reeks \(run.length) (\(name(for: run.player)))")
        }
        lines.append(stats.joined(separator: " · "))
        lines.append("")
        lines.append("_Gescoord met Squash Analyzer_")
        return lines.joined(separator: "\n")
    }
}

/// The three WhatsApp layouts offered by the referee share sheet
enum RefereeShareStyle: String, CaseIterable, Identifiable {
    case compact, scorecard, report

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: return "Kort"
        case .scorecard: return "Scorekaart"
        case .report: return "Verslag"
        }
    }

    var subtitle: String {
        switch self {
        case .compact: return "Drie regels voor de groepsapp"
        case .scorecard: return "Tabel met alle games"
        case .report: return "Per game, met tijden en statistieken"
        }
    }
}
