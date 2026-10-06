import Foundation

// MARK: - Verslag

/// The team match as a WhatsApp message, in the layouts of "Deel score":
/// Scorekaart (a monospace table), Verslag (per partij) and the short
/// three-liner. The picture is `ResultCard.from(_:)` below.
public enum TeamMatchReport {
    /// The full report ("Verslag")
    public static func text(_ match: TeamMatch) -> String {
        text(match, style: MatchShareStyle.report)
    }

    public static func text(_ match: TeamMatch, style: MatchShareStyle) -> String {
        switch style {
        case .compact: return compact(match)
        case .scorecard: return scorecard(match)
        case .report: return report(match)
        }
    }

    // Building blocks

    /// "9–8" in games, the winner's games first
    private static func winnerScore(_ match: TeamMatch) -> String {
        let own = match.score.ownGames
        let their = match.score.theirGames
        return own >= their ? "\(own)–\(their)" : "\(their)–\(own)"
    }

    /// The result, or the stand while the team match is not over
    static func resultLine(_ match: TeamMatch) -> String {
        let current = match.score
        if current.isComplete {
            if let winner = match.winnerName { return "🏆 *\(winner) wint met \(winnerScore(match))*" }
            return "🤝 *Gelijkspel \(match.homeGames)–\(match.awayGames)*"
        }
        if current.partijenPlayed == 0 { return "Nog niet begonnen" }
        if current.ownGames == current.theirGames { return "Stand: gelijk \(match.homeGames)–\(match.awayGames)" }
        let leader = current.ownGames > current.theirGames ? match.ownName : match.opponentName
        return "Stand: \(leader) leidt met \(winnerScore(match)) · \(current.partijenPlayed) van 4 partijen"
    }

    /// "Competitiepunten: All Inn 12 · Delft 8" once the match is decided
    static func pointsLine(_ match: TeamMatch) -> String? {
        guard match.score.isComplete else { return nil }
        return "Competitiepunten: \(match.home) \(match.homeCompetitionPoints) · \(match.away) \(match.awayCompetitionPoints)"
    }

    /// Home player first, as SBN prints it; a missing name is "Squash Delft 8 E1"
    static func names(_ partij: TeamPartij, match: TeamMatch) -> String {
        let own = match.ownDisplayName(partij)
        let their = match.opponentDisplayName(partij)
        return match.ownSide == TeamSide.home ? "\(own) – \(their)" : "\(their) – \(own)"
    }

    /// The last two words of a team name, for the narrow scorecard: "Squash Delft 8" → "Delft 8"
    static func shortTeam(_ name: String) -> String {
        let words = name.components(separatedBy: " ")
        if words.count <= 2 { return name }
        return words[words.count - 2] + " " + words[words.count - 1]
    }

    /// "3-1" of a partij, home first
    static func standText(_ partij: TeamPartij, match: TeamMatch) -> String {
        match.ownSide == TeamSide.home ? "\(partij.ownGames)-\(partij.theirGames)" : "\(partij.theirGames)-\(partij.ownGames)"
    }

    /// "11-8, 9-11", home first
    static func gamesText(_ partij: TeamPartij, match: TeamMatch) -> String {
        match.ownSide == TeamSide.home ? partij.gamesText : flipped(partij)
    }

    static func flipped(_ partij: TeamPartij) -> String {
        var parts: [String] = []
        for game in partij.games {
            if let own = game.ownPoints, let their = game.theirPoints {
                parts.append("\(their)-\(own)")
            } else {
                parts.append("–")
            }
        }
        return parts.joined(separator: ", ")
    }

    private static func sorted(_ match: TeamMatch) -> [TeamPartij] {
        match.partijen.sorted(by: { a, b in a.slot < b.slot })
    }

    // 1. Kort

    private static func compact(_ match: TeamMatch) -> String {
        var lines: [String] = []
        lines.append("🏆 *Teamwedstrijd · \(shortDay(match.date))*")
        let homeLeads = match.homeGames > match.awayGames
        let awayLeads = match.awayGames > match.homeGames
        let home = homeLeads ? "*\(match.home)*" : match.home
        let away = awayLeads ? "*\(match.away)*" : match.away
        lines.append("\(home) \(match.homeGames) – \(match.awayGames) \(away)")
        var detail = "\(match.homePartijen)-\(match.awayPartijen) in partijen"
        if let points = pointsLine(match) { detail += " · " + points.replacingOccurrences(of: "Competitiepunten: ", with: "punten ") }
        lines.append(detail)
        return lines.joined(separator: "\n")
    }

    // 2. Scorekaart

    /// Monospace table: per partij the home and the away player, one column per game
    private static func scorecard(_ match: TeamMatch) -> String {
        let nameWidth = 12
        // Every row has as many game columns as the longest partij, so the
        // column with the games won lines up
        var columns = 1
        for partij in match.partijen where partij.games.count > columns { columns = partij.games.count }
        func pad(_ s: String, _ w: Int, right: Bool = false) -> String {
            let t = String(s.prefix(w))
            let fill = String(repeating: " ", count: max(0, w - t.count))
            return right ? fill + t : t + fill
        }
        var lines: [String] = []
        lines.append("🏆 *TEAM SCOREKAART*")
        lines.append("\(shortDay(match.date)) · \(match.home) – \(match.away)")
        lines.append("")
        lines.append("```")
        for partij in sorted(match) {
            let own = partij.ownPlayer.isEmpty ? shortTeam(match.ownName) : partij.ownPlayer
            let their = partij.opponentPlayer.isEmpty ? shortTeam(match.opponentName) : partij.opponentPlayer
            let homeName = match.ownSide == TeamSide.home ? own : their
            let awayName = match.ownSide == TeamSide.home ? their : own
            var row1 = pad(partij.label + " " + homeName, nameWidth)
            var row2 = pad("   " + awayName, nameWidth)
            for game in partij.games {
                let homePoints = match.ownSide == TeamSide.home ? game.ownPoints : game.theirPoints
                let awayPoints = match.ownSide == TeamSide.home ? game.theirPoints : game.ownPoints
                row1 += pad(homePoints.map { value in String(value) } ?? "–", 4, right: true)
                row2 += pad(awayPoints.map { value in String(value) } ?? "–", 4, right: true)
            }
            for _ in partij.games.count..<columns {
                row1 += "    "
                row2 += "    "
            }
            if partij.hasEntry {
                row1 += "  " + String(standText(partij, match: match).prefix(1))
                row2 += "  " + String(standText(partij, match: match).suffix(1))
            }
            lines.append(row1)
            lines.append(row2)
        }
        lines.append("```")
        lines.append(resultLine(match))
        if let points = pointsLine(match) { lines.append(points) }
        return lines.joined(separator: "\n")
    }

    // 3. Verslag

    private static func report(_ match: TeamMatch) -> String {
        var lines: [String] = []
        lines.append("🏆 *TEAMWEDSTRIJD*")
        lines.append("📅 \(longDay(match.date))")
        lines.append("👥 \(match.home) – \(match.away)")
        lines.append("")
        for partij in sorted(match) {
            let who = names(partij, match: match)
            // No names filled in: the default names already carry the E1
            let bare = partij.ownPlayer.isEmpty && partij.opponentPlayer.isEmpty
            let prefix = bare ? "" : "*\(partij.label)* "
            if !partij.hasEntry {
                lines.append(bare ? "*\(partij.label)* nog niet gespeeld" : "\(prefix)\(who): nog niet gespeeld")
            } else {
                var line = "\(prefix)\(who) · \(standText(partij, match: match)) (\(gamesText(partij, match: match)))"
                if let won = partij.ownWon {
                    let winner = won ? match.ownDisplayName(partij) : match.opponentDisplayName(partij)
                    line += " ✅ \(winner)"
                }
                lines.append(line)
            }
        }
        lines.append("")
        lines.append(resultLine(match))
        let current = match.score
        var stats = ["🎯 \(match.homePartijen)-\(match.awayPartijen) in partijen"]
        if current.pointsKnown && current.partijenPlayed > 0 {
            stats.append("🎾 rallypunten \(match.ownSide == TeamSide.home ? current.ownPoints : current.theirPoints)-\(match.ownSide == TeamSide.home ? current.theirPoints : current.ownPoints)")
        }
        lines.append(stats.joined(separator: " · "))
        if let points = pointsLine(match) { lines.append(points) }
        lines.append("")
        lines.append("_Gescoord met Squash Analyzer_")
        return lines.joined(separator: "\n")
    }

    // Dates (DateFormatter: Date.FormatStyle does not exist in Skip)

    private static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    /// "vr 30 okt"
    public static func dayText(_ date: Date) -> String { format(date, "EEE d MMM") }
    static func shortDay(_ date: Date) -> String { dayText(date) }
    /// "vrijdag 30 oktober 2026"
    static func longDay(_ date: Date) -> String { format(date, "EEEE d MMMM yyyy") }
}

extension ResultCard {
    /// The picture of a team match: both team names, the games as the big
    /// score (home is the orange side), who won, and a chip per partij.
    public static func from(_ match: TeamMatch) -> ResultCard {
        var chips: [Chip] = []
        for partij in match.partijen.sorted(by: { a, b in a.slot < b.slot }) where partij.hasEntry {
            var winner: Player? = nil
            if let ownWon = partij.ownWon {
                let homeWon = ownWon == (match.ownSide == TeamSide.home)
                winner = homeWon ? Player.player1 : Player.player2
            }
            chips.append(Chip(label: partij.label, score: TeamMatchReport.standText(partij, match: match), winner: winner))
        }
        let current = match.score
        var winner: Player? = nil
        var text: String? = nil
        var title = "TUSSENSTAND"
        if current.isComplete {
            title = "TEAMWEDSTRIJD KLAAR"
            if let ownWon = current.ownWon {
                let homeWon = ownWon == (match.ownSide == TeamSide.home)
                winner = homeWon ? Player.player1 : Player.player2
                text = "\(match.winnerName ?? "") wint de teamwedstrijd"
            } else {
                text = "Gelijkspel"
            }
        } else if current.partijenPlayed == 0 {
            title = "TEAMWEDSTRIJD"
        } else if match.homeGames != match.awayGames {
            winner = match.homeGames > match.awayGames ? Player.player1 : Player.player2
            text = "\(match.homeGames > match.awayGames ? match.home : match.away) leidt \(max(match.homeGames, match.awayGames))-\(min(match.homeGames, match.awayGames))"
        }
        return ResultCard(title: title, player1Name: match.home, player2Name: match.away,
                          player1Score: match.homeGames, player2Score: match.awayGames,
                          winner: winner, winnerText: text, chips: chips)
    }
}
