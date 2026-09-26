import Foundation

/// A match as the WhatsApp share texts see it. Coach mode (`Match.shareReport`)
/// and referee mode (`RefereeMatch.shareReport`) both build one, so the three
/// layouts and the share sheet are the same in both modes.
struct MatchShareReport {
    /// One game: finished, or the game on the board while a rally has been played
    struct Game {
        let number: Int
        let player1Score: Int
        let player2Score: Int
        /// nil while the game is still in progress
        let winner: Player?
        let duration: TimeInterval?
        /// Rally winners in play order (for the longest run)
        let rallyWinners: [Player]
        let strokes: Int

        var rallies: Int { player1Score + player2Score }

        /// Longest run of consecutive rallies won by one player
        var longestRun: (player: Player, length: Int)? {
            var best: (Player, Int)? = nil
            var current: (Player, Int)? = nil
            for scorer in rallyWinners {
                if let c = current, c.0 == scorer {
                    current = (c.0, c.1 + 1)
                } else {
                    current = (scorer, 1)
                }
                if let c = current, c.1 > (best?.1 ?? 0) { best = c }
            }
            return best.map { (player: $0.0, length: $0.1) }
        }
    }

    let player1Name: String
    let player2Name: String
    let bestOf: Int
    /// 1, or the game at which tracking started ("later instappen")
    let firstGameNumber: Int
    /// Games won, including games before tracking started and filled-in ones
    let player1Games: Int
    let player2Games: Int
    /// nil while the match is not decided
    let matchWinner: Player?
    let games: [Game]
    let startedAt: Date
    let duration: TimeInterval

    func name(for player: Player) -> String { player == .player1 ? player1Name : player2Name }

    var totalRallies: Int { games.reduce(0) { $0 + $1.rallies } }
    var totalStrokes: Int { games.reduce(0) { $0 + $1.strokes } }

    /// Longest run of consecutive rallies won by one player anywhere in the match
    var longestRun: (player: Player, length: Int)? {
        games.compactMap(\.longestRun).max { $0.length < $1.length }
    }

    func text(style: MatchShareStyle) -> String {
        switch style {
        case .compact: return compactShareText
        case .scorecard: return scorecardShareText
        case .report: return reportShareText
        }
    }

    // Shared building blocks -------------------------------------------------

    private static let dutch = Locale(identifier: "nl_NL")

    private var shortDateText: String {
        startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Self.dutch))
    }

    private var longDateText: String {
        startedAt.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(Self.dutch))
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
    private var gamesScoreText: String { "\(player1Games) – \(player2Games)" }

    /// "Jan 3 – 1 Piet" with the winner (or leader) in bold, in player order
    private var namesAndGamesLine: String {
        let p1 = player1Games, p2 = player2Games
        let name1 = p1 > p2 ? "*\(player1Name)*" : player1Name
        let name2 = p2 > p1 ? "*\(player2Name)*" : player2Name
        return "\(name1) \(p1) – \(p2) \(name2)"
    }

    /// Match result or, mid-match, the current stand
    private var resultLine: String {
        if let winner = matchWinner {
            let score = winner == .player1 ? "\(player1Games)–\(player2Games)" : "\(player2Games)–\(player1Games)"
            return "🏆 *\(name(for: winner)) wint met \(score)*"
        }
        if player1Games == player2Games {
            return "Stand: gelijk \(gamesScoreText)"
        }
        let leader: Player = player1Games > player2Games ? .player1 : .player2
        let score = leader == .player1 ? "\(player1Games)–\(player2Games)" : "\(player2Games)–\(player1Games)"
        return "Stand: \(name(for: leader)) leidt met \(score)"
    }

    /// "11-13 · 11-4 · 11-3", an unfinished game shown as "5-3…"
    private var gameScoresInline: String {
        games.map { g in
            "\(g.player1Score)-\(g.player2Score)" + (g.winner == nil ? "…" : "")
        }.joined(separator: " · ")
    }

    // 1. Kort ---------------------------------------------------------------

    /// Three lines for a quick group-chat update
    private var compactShareText: String {
        var lines: [String] = []
        lines.append("🏸 *Squash · \(bestOfText)*")
        lines.append((matchWinner != nil ? "🏆 " : "") + namesAndGamesLine)
        if !games.isEmpty { lines.append(gameScoresInline) }
        lines.append("⏱ \(minutesText(duration)) · \(shortDateText)")
        return lines.joined(separator: "\n")
    }

    // 2. Scorekaart ---------------------------------------------------------

    /// Monospace score table, one column per game
    private var scorecardShareText: String {
        let games = games
        let nameWidth = 10
        func pad(_ s: String, _ w: Int, right: Bool = false) -> String {
            let t = String(s.prefix(w))
            let fill = String(repeating: " ", count: max(0, w - t.count))
            return right ? fill + t : t + fill
        }

        var lines: [String] = []
        lines.append("🏸 *SQUASH SCOREKAART*")
        lines.append("\(shortDateText) · \(bestOfText) · ⏱ \(minutesText(duration))")
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

        for g in games {
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
        if !games.isEmpty { lines.append("") }

        lines.append(resultLine)

        var stats = ["⏱ \(minutesText(duration))", "🎾 \(totalRallies) rallies"]
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

/// The three WhatsApp layouts offered by the share sheet (coach and referee)
enum MatchShareStyle: String, CaseIterable, Identifiable {
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
