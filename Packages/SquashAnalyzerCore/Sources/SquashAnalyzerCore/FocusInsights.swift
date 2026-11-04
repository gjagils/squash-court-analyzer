import Foundation

// The coaching focus against the numbers (backlog C7, 4 November 2026). A
// player's focus tags (Spelers, copied into the match at setup) used to stand
// apart from the analysis; now each tag gets one line with what this game
// says about it. Facts and counts, not advice: the advice is CoachAdvice.
// Shared by iOS and Android.

/// One focus tag with what the game's numbers say about it
public struct FocusInsight: Identifiable, Equatable, Sendable {
    public let tag: CoachingFocusTag
    /// "Linkerkant: 4 gewonnen, 6 verloren. Beste slag daar: drive (3)."
    public let text: String

    public var id: String { tag.rawValue }

    public init(tag: CoachingFocusTag, text: String) {
        self.tag = tag
        self.text = text
    }
}

public enum FocusInsights {
    /// At least this many points before a shot is named "beste slag daar"
    static let minimumShotPoints = 2
    /// The closing phase of a game: from this score errors weigh on the mind
    static let closingScore = 8

    /// One line per focus tag of `player`, in the order of the focus list.
    /// Tags the app does not know (older imports) are skipped. With
    /// `simpleInput` (Eenvoudig coachen) there are no shots, winners or
    /// errors, so the lines that need them say so.
    public static func make(in game: Game, for player: Player, focus: [String], simpleInput: Bool = false) -> [FocusInsight] {
        var result: [FocusInsight] = []
        for raw in focus {
            var found: CoachingFocusTag? = nil
            for candidate in CoachingFocusTag.allCases where candidate.rawValue == raw {
                found = candidate
            }
            guard let tag = found else { continue }
            result.append(FocusInsight(tag: tag, text: line(tag, in: game, for: player, simpleInput: simpleInput)))
        }
        return result
    }

    /// (Not `text(for:in:for:)`: two `for` labels become one Kotlin parameter name in Skip)
    static func line(_ tag: CoachingFocusTag, in game: Game, for player: Player, simpleInput: Bool) -> String {
        switch tag {
        case .voorhand: return sideText(CourtSide.right, in: game, for: player, simpleInput: simpleInput)
        case .backhand: return sideText(CourtSide.left, in: game, for: player, simpleInput: simpleInput)
        case .serve: return serveText(in: game, for: player, simpleInput: simpleInput)
        case .volley: return volleyText(in: game, for: player, simpleInput: simpleInput)
        case .drop: return dropText(in: game, for: player, simpleInput: simpleInput)
        case .boast: return boastText(in: game, for: player, simpleInput: simpleInput)
        case .achterwand: return backText(in: game, for: player, simpleInput: simpleInput)
        case .conditie: return staminaText(in: game, for: player)
        case .snelheid: return speedText(in: game, for: player, simpleInput: simpleInput)
        case .beweging: return movementText(in: game, for: player, simpleInput: simpleInput)
        case .mentaal: return mentalText(in: game, for: player, simpleInput: simpleInput)
        case .tactiek: return tacticsText(in: game, for: player, simpleInput: simpleInput)
        }
    }

    // MARK: Lines

    /// Voorhand (right) and Backhand (left) of a right-handed player: what
    /// was won and lost on that side, and the shot that scored most there.
    /// The line names the side on purpose: the app does not know who is
    /// left-handed (docs/bewuste-keuzes.md).
    static func sideText(_ side: CourtSide, in game: Game, for player: Player, simpleInput: Bool) -> String {
        let profile = ZoneProfile.of(game, for: player)
        let won = profile.won.count(side)
        let lost = profile.lost.count(side)
        let name = side == CourtSide.left ? L10n.text("Linkerkant") : L10n.text("Rechterkant")
        if won + lost == 0 {
            return L10n.text("%@: nog geen punten.", name)
        }
        var text = L10n.text("%@: %@ gewonnen, %@ verloren.", name, "\(won)", "\(lost)")
        if !simpleInput, let best = bestShot(in: game, for: player, matching: { point in point.zone?.side == side }) {
            text += " " + L10n.text("Beste slag daar: %@ (%@).", best.shot.rawValue.lowercased(), "\(best.count)")
        }
        return text
    }

    /// Points on the player's own serve, aces and service faults
    static func serveText(in game: Game, for player: Player, simpleInput: Bool) -> String {
        let stats = ServiceReturnStats.of(game, for: player)
        if stats.served == 0 {
            return L10n.text("Nog niet geserveerd.")
        }
        var text = L10n.text("Op eigen service %@ van %@ punten gewonnen.", "\(stats.wonOnServe)", "\(stats.served)")
        if !simpleInput {
            let aces = game.servicePoints(by: player).count
            let faults = game.errorKindCounts(madeBy: player)[ErrorKind.service] ?? 0
            text += " " + L10n.text("Servicepunten %@, servicefouten %@.", "\(aces)", "\(faults)")
        }
        return text
    }

    /// Points won out of the air, by shot, and the opponent's
    static func volleyText(in game: Game, for player: Player, simpleInput: Bool) -> String {
        if simpleInput { return notRecorded }
        let count = game.volleysWon(by: player).count
        if count == 0 {
            return L10n.text("Nog geen punten uit de lucht.")
        }
        let breakdown = CoachAdvice.volleyBreakdown(in: game, for: player) ?? ""
        return L10n.text("%@ uit de lucht (%@).", points(count), breakdown) + " " + opponentCount(game.volleysWon(by: player.opponent).count, in: game, for: player)
    }

    /// Points with a drop (also a volley drop), and the front of the court
    static func dropText(in game: Game, for player: Player, simpleInput: Bool) -> String {
        if simpleInput { return notRecorded }
        let profile = ZoneProfile.of(game, for: player)
        let drops = shotPoints(ShotType.drop, in: game, for: player)
        let front = L10n.text("Voorin %@ gewonnen, %@ verloren.", "\(profile.won.front)", "\(profile.lost.front)")
        if drops == 0 {
            return L10n.text("Nog geen punt met een drop.") + " " + front
        }
        return L10n.text("%@ met een drop.", points(drops)) + " " + front
    }

    /// Points with a boast, and the opponent's
    static func boastText(in game: Game, for player: Player, simpleInput: Bool) -> String {
        if simpleInput { return notRecorded }
        let boasts = shotPoints(ShotType.boast, in: game, for: player)
        let opponent = opponentCount(shotPoints(ShotType.boast, in: game, for: player.opponent), in: game, for: player)
        if boasts == 0 {
            return L10n.text("Nog geen punt met een boast.") + " " + opponent
        }
        return L10n.text("%@ met een boast.", points(boasts)) + " " + opponent
    }

    /// Achterwand: the back of the court, and the shot that scored most there
    static func backText(in game: Game, for player: Player, simpleInput: Bool) -> String {
        let profile = ZoneProfile.of(game, for: player)
        let won = profile.won.back
        let lost = profile.lost.back
        if won + lost == 0 {
            return L10n.text("Achterin nog geen punten.")
        }
        var text = L10n.text("Achterin %@ gewonnen, %@ verloren.", "\(won)", "\(lost)")
        if !simpleInput, let best = bestShot(in: game, for: player, matching: { point in point.zone?.row == CourtRow.back }) {
            text += " " + L10n.text("Beste slag daar: %@ (%@).", best.shot.rawValue.lowercased(), "\(best.count)")
        }
        return text
    }

    /// Conditie: long against short rallies, and the longest one
    static func staminaText(in game: Game, for player: Player) -> String {
        guard let long = game.longRallyWinPercentage(for: player),
              let short = game.shortRallyWinPercentage(for: player),
              let longest = game.longestPoint() else {
            return tooFewTimed
        }
        return L10n.text("Lange rally's %@% gewonnen, korte %@%. Langste rally %@.",
                         "\(Int(long.rounded()))", "\(Int(short.rounded()))", CoachAdvice.formatDuration(longest.duration))
    }

    /// Snelheid: points lost under pressure (too late at the ball) and the short rallies
    static func speedText(in game: Game, for player: Player, simpleInput: Bool) -> String {
        var parts: [String] = []
        if !simpleInput {
            let forced = game.forcedErrors(by: player.opponent).count
            parts.append(L10n.text("%@ verloren onder druk (forced error).", points(forced)))
        }
        if let short = game.shortRallyWinPercentage(for: player) {
            parts.append(L10n.text("Korte rally's %@% gewonnen.", "\(Int(short.rounded()))"))
        }
        if parts.isEmpty { return tooFewTimed }
        return parts.joined(separator: " ")
    }

    /// Beweging: lets both ways and strokes against (not clearing in time)
    static func movementText(in game: Game, for player: Player, simpleInput: Bool) -> String {
        let letsFor = game.letsRequested(by: player).count
        let letsAgainst = game.letsRequested(by: player.opponent).count
        if simpleInput {
            return L10n.text("Lets mee %@, lets tegen %@.", "\(letsFor)", "\(letsAgainst)")
        }
        let strokesAgainst = game.strokes(by: player.opponent).count
        return L10n.text("Lets mee %@, lets tegen %@, strokes tegen %@.", "\(letsFor)", "\(letsAgainst)", "\(strokesAgainst)")
    }

    /// Mentaal: own errors, the ones in the closing phase, and the longest run of points lost
    static func mentalText(in game: Game, for player: Player, simpleInput: Bool) -> String {
        if game.points.isEmpty {
            return L10n.text("Nog geen punten.")
        }
        let streak = longestLosingStreak(in: game, for: player)
        if simpleInput {
            return L10n.text("Langste reeks verloren punten: %@.", "\(streak)")
        }
        let errors = game.unforcedErrors(by: player.opponent)
        var late = 0
        for point in errors where max(point.player1Score, point.player2Score) >= closingScore {
            late += 1
        }
        if errors.count == 1 {
            return L10n.text("1 eigen fout, %@ vanaf een stand van 8. Langste reeks verloren punten: %@.", "\(late)", "\(streak)")
        }
        return L10n.text("%@ eigen fouten, %@ vanaf een stand van 8. Langste reeks verloren punten: %@.", "\(errors.count)", "\(late)", "\(streak)")
    }

    /// Tactiek: best zone, best shot and how many different shots scored
    static func tacticsText(in game: Game, for player: Player, simpleInput: Bool) -> String {
        guard let zone = game.bestZone(for: player) else {
            return L10n.text("Nog geen punten met een vak.")
        }
        if simpleInput {
            return L10n.text("Beste zone %@.", zone.title)
        }
        guard let shot = game.bestShotType(for: player) else {
            return L10n.text("Beste zone %@.", zone.title)
        }
        var used: [ShotType] = []
        for point in game.attackingPoints(by: player) {
            if let shotType = point.shotType, !used.contains(shotType) { used.append(shotType) }
        }
        return L10n.text("Beste zone %@, beste slag %@, %@ verschillende slagen.", zone.title, shot.rawValue.lowercased(), "\(used.count)")
    }

    // MARK: Helpers

    static var notRecorded: String { L10n.text("Niet vastgelegd bij Eenvoudig coachen.") }
    static var tooFewTimed: String { L10n.text("Nog te weinig getimede rally's.") }

    /// "1 punt", "4 punten"
    static func points(_ count: Int) -> String {
        count == 1 ? L10n.text("1 punt") : L10n.text("%@ punten", "\(count)")
    }

    /// "Jaïr: 2."
    static func opponentCount(_ count: Int, in game: Game, for player: Player) -> String {
        L10n.text("%@: %@.", game.name(for: player.opponent), "\(count)")
    }

    /// Winners and forced errors with `shot`, off the bounce or as a volley
    static func shotPoints(_ shot: ShotType, in game: Game, for player: Player) -> Int {
        var count = 0
        for point in game.attackingPoints(by: player) where point.shotType == shot {
            count += 1
        }
        return count
    }

    /// The shot that scored most among the player's attacking points that
    /// pass `include`, with at least `minimumShotPoints`; a volley counts as
    /// the same shot
    static func bestShot(in game: Game, for player: Player, matching include: (Point) -> Bool) -> ShotCount? {
        var best: ShotCount? = nil
        for shot in ShotType.allCases {
            var count = 0
            for point in game.attackingPoints(by: player) where point.shotType == shot && include(point) {
                count += 1
            }
            if count >= minimumShotPoints && count > (best?.count ?? 0) {
                best = ShotCount(shot: shot, count: count)
            }
        }
        return best
    }

    /// The most points in a row the opponent won
    static func longestLosingStreak(in game: Game, for player: Player) -> Int {
        var longest = 0
        var current = 0
        for point in game.points {
            if point.scorer == player {
                current = 0
            } else {
                current += 1
                if current > longest { longest = current }
            }
        }
        return longest
    }
}
