import Foundation

/// One possible advice line with what it is worth: `potential` is the number
/// of points at stake (lost points or chances; things that already go well
/// count for less), `key` names the finding so the same one in another game
/// is recognised as a pattern, and `order` breaks ties in a fixed order.
struct AdviceCandidate {
    let item: AdviceItem
    let potential: Double
    let key: String
    let order: Int
}

/// The rules behind CoachAdvice.local, one game at a time. Thresholds:
/// AreaTally ("vaak"), 3 points for shots, zones and volleys.
enum AdviceRules {
    /// Things that go well are worth keeping, but less than points to win back
    static let keepGoingWeight = 0.6
    static let minimumPoints = 3

    static func candidates(in game: Game, for player: Player) -> [AdviceCandidate] {
        let opponent = player.opponent
        let opponentName = game.name(for: opponent)
        let profile = ZoneProfile.of(game, for: player)
        let opponentErrors = ZoneProfile.of(game, for: opponent).errors
        var result: [AdviceCandidate] = []

        func add(_ topic: AdviceTopic, _ tone: AdviceTone, _ text: String, _ potential: Double, _ key: String) {
            result.append(AdviceCandidate(item: AdviceItem(topic: topic, tone: tone, text: text),
                                          potential: potential, key: key, order: result.count + 1))
        }

        if let tempo = tempoCandidate(in: game, for: player) {
            result.append(tempo)
        }

        // Where the player loses points
        if let row = profile.lost.dominantRow {
            let count = profile.lost.count(row)
            let tip: String
            switch row {
            case .front: tip = L10n.text("%@ maakt het kort af: sta dichter bij de T en reageer eerder op korte ballen.", "\(opponentName)")
            case .middle: tip = L10n.text("%@ neemt de bal vroeg: houd je slagen strakker langs de muur.", "\(opponentName)")
            case .back: tip = L10n.text("%@ drukt je naar achteren: werk aan je terugslag uit de achterhoek en speel zelf meer lengte.", "\(opponentName)")
            }
            add(AdviceTopic.lostArea, AdviceTone.warning,
                L10n.text("Je verliest de meeste punten %@ (%@ van %@). %@", "\(row.inWords)", "\(count)", "\(profile.lost.total)", "\(tip)"),
                Double(count), "verloren-\(row.rawValue)")
        }
        if let side = profile.lost.dominantSide {
            let count = profile.lost.count(side)
            add(AdviceTopic.lostArea, AdviceTone.warning,
                L10n.text("Je verliest de meeste punten %@ (%@ van %@). Daar is %@ sterk.", "\(side.inWords)", "\(count)", "\(profile.lost.sideTotal)", "\(opponentName)"),
                Double(count), "verloren-\(side.rawValue)")
        }

        // Where the player errs
        if let row = profile.errors.dominantRow {
            let count = profile.errors.count(row)
            let tip: String
            switch row {
            case .front: tip = L10n.text("Speel daar wat hoger en veiliger.")
            case .middle: tip = L10n.text("Neem de tijd, ook als de bal makkelijk lijkt.")
            case .back: tip = L10n.text("Kies uit de achterhoek vaker de veilige lengte.")
            }
            add(AdviceTopic.errorArea, AdviceTone.warning,
                L10n.text("%@ van je %@ fouten maak je %@. %@", "\(count)", "\(profile.errors.total)", "\(row.inWords)", "\(tip)"),
                Double(count), "fouten-\(row.rawValue)")
        }
        if let side = profile.errors.dominantSide {
            let count = profile.errors.count(side)
            add(AdviceTopic.errorArea, AdviceTone.warning,
                L10n.text("Je fouten vallen vooral %@ (%@ van %@). Speel daar wat veiliger.", "\(side.inWords)", "\(count)", "\(profile.errors.sideTotal)"),
                Double(count), "fouten-\(side.rawValue)")
        }

        // Where the opponent errs: a chance
        if let row = opponentErrors.dominantRow {
            let count = opponentErrors.count(row)
            let tip: String
            switch row {
            case .front: tip = L10n.text("Dwing %@ naar voren.", "\(opponentName)")
            case .middle: tip = L10n.text("Speel strak door het midden, daar gaat %@ in de fout.", "\(opponentName)")
            case .back: tip = L10n.text("Speel %@ naar de achterhoeken.", "\(opponentName)")
            }
            add(AdviceTopic.opening, AdviceTone.success,
                L10n.text("%@ maakt de meeste fouten %@ (%@ van %@). %@", "\(opponentName)", "\(row.inWords)", "\(count)", "\(opponentErrors.total)", "\(tip)"),
                Double(count), "kans-\(row.rawValue)")
        }
        if let side = opponentErrors.dominantSide {
            let count = opponentErrors.count(side)
            add(AdviceTopic.opening, AdviceTone.success,
                L10n.text("%@ maakt de meeste fouten %@ (%@ van %@). Speel die kant op.", "\(opponentName)", "\(side.inWords)", "\(count)", "\(opponentErrors.sideTotal)"),
                Double(count), "kans-\(side.rawValue)")
        }

        // Errors, pressure, lets and service (the rules from before)
        let ownErrors = game.unforcedErrors(by: opponent).count
        let errorRate = game.points.isEmpty ? 0.0 : Double(ownErrors) / Double(game.points.count)
        if ownErrors >= 3 {
            add(AdviceTopic.ownErrors, AdviceTone.warning, L10n.text("%@ eigen fouten: blijf geconcentreerd en speel rustig.", "\(ownErrors)"),
                Double(ownErrors), "eigen-fouten")
        } else if ownErrors >= 2 && errorRate > 0.25 {
            add(AdviceTopic.hurry, AdviceTone.warning, L10n.text("Minder haast: neem meer tijd voor je slagen."), Double(ownErrors), "haast")
        }
        // The kind of error that keeps coming back (Down/Out/Service/Grond)
        if let common = mostCommonErrorKind(in: game, madeBy: player) {
            add(AdviceTopic.ownErrors, AdviceTone.warning, errorKindTip(common.kind, count: common.count),
                Double(common.count), "fout-\(common.kind.rawValue)")
        }
        let forcedAgainst = game.forcedErrors(by: opponent).count
        if forcedAgainst >= 3 {
            add(AdviceTopic.forcedErrors, AdviceTone.warning, L10n.text("%@ forced errors: heb je racket eerder klaar voor je slag.", "\(forcedAgainst)"),
                Double(forcedAgainst), "forced-errors")
        }
        let letsAgainst = game.letsRequested(by: opponent).count
        let letsFor = game.letsRequested(by: player).count
        if letsAgainst >= 2 {
            add(AdviceTopic.letsAgainst, AdviceTone.warning, L10n.text("%@ lets tegen: beweeg na je slag sneller terug naar de T.", "\(letsAgainst)"),
                Double(letsAgainst), "lets-tegen")
        }
        let opponentServicePoints = game.servicePoints(by: opponent).count
        if opponentServicePoints >= 2 {
            add(AdviceTopic.opponentServicePoints, AdviceTone.warning,
                L10n.text("%@ scoort %@ servicepunten: houd je racket vroeg omhoog bij de return.", "\(opponentName)", "\(opponentServicePoints)"),
                Double(opponentServicePoints), "service-tegen")
        }
        if let zone = game.bestZone(for: opponent) {
            var count = 0
            for point in game.attackingPoints(by: opponent) where point.zone == zone {
                count += 1
            }
            if count >= minimumPoints {
                add(AdviceTopic.avoidZone, AdviceTone.warning,
                    L10n.text("Vermijd %@: daar scoort %@ het meest (%@ punten).", "\(zone.title)", "\(opponentName)", "\(count)"),
                    Double(count) * 0.8, "vermijd-\(zone.rawValue)")
            }
        }
        let opponentVolleys = game.volleysWon(by: opponent).count
        if opponentVolleys >= minimumPoints {
            add(AdviceTopic.opponentVolleys, AdviceTone.warning,
                L10n.text("%@ wint %@ punten uit de lucht. Speel hoger over of strakker langs de muur.", "\(opponentName)", "\(opponentVolleys)"),
                Double(opponentVolleys), "volleys-tegen")
        }

        // What goes well
        if let row = profile.won.dominantRow {
            let count = profile.won.count(row)
            let tip: String
            switch row {
            case .front: tip = L10n.text("Blijf de voorhoeken zoeken.")
            case .middle: tip = L10n.text("Blijf de T pakken en de bal vroeg nemen.")
            case .back: tip = L10n.text("Je lengte werkt, blijf druk zetten op de achterwand.")
            }
            add(AdviceTopic.wonArea, AdviceTone.success,
                L10n.text("Je wint je punten vooral %@ (%@ van %@). %@", "\(row.inWords)", "\(count)", "\(profile.won.total)", "\(tip)"),
                Double(count) * keepGoingWeight, "gewonnen-\(row.rawValue)")
        }
        if let side = profile.won.dominantSide {
            let count = profile.won.count(side)
            add(AdviceTopic.wonArea, AdviceTone.success,
                L10n.text("Je scoort vooral %@ (%@ van %@). Speel vaker die kant op.", "\(side.inWords)", "\(count)", "\(profile.won.sideTotal)"),
                Double(count) * keepGoingWeight, "gewonnen-\(side.rawValue)")
        }
        let opponentErrorCount = game.unforcedErrors(by: player).count
        if opponentErrorCount >= 3 {
            add(AdviceTopic.opponentErrors, AdviceTone.success, L10n.text("%@ maakt %@ fouten: blijf druk zetten.", "\(opponentName)", "\(opponentErrorCount)"),
                Double(opponentErrorCount) * keepGoingWeight, "fouten-tegenstander")
        }
        let ownServicePoints = game.servicePoints(by: player).count
        if ownServicePoints >= 2 {
            add(AdviceTopic.ownServicePoints, AdviceTone.success,
                L10n.text("Je scoort %@ servicepunten: je service werkt, blijf zo serveren.", "\(ownServicePoints)"),
                Double(ownServicePoints) * keepGoingWeight, "service-mee")
        }
        if letsFor >= 2 && letsAgainst < 2 {
            add(AdviceTopic.letsFor, AdviceTone.success, L10n.text("%@ lets mee: je beweegt goed naar de bal.", "\(letsFor)"),
                Double(letsFor) * 0.5, "lets-mee")
        }
        let ownVolleys = game.volleysWon(by: player).count
        if ownVolleys >= minimumPoints {
            add(AdviceTopic.volleys, AdviceTone.success,
                L10n.text("Je wint %@ punten uit de lucht. Blijf de bal vroeg nemen, dat zet druk.", "\(ownVolleys)"),
                Double(ownVolleys) * keepGoingWeight, "volleys-mee")
        }
        for row in [CourtRow.front, CourtRow.middle, CourtRow.back] {
            if let best = bestShot(in: game, for: player, row: row) {
                let place = row == CourtRow.front ? L10n.text("Voorin") : (row == CourtRow.middle ? L10n.text("In het midden") : L10n.text("Achterin"))
                add(AdviceTopic.bestShot, AdviceTone.info,
                    L10n.text("%@ werkt je %@ het best (%@ punten).", "\(place)", "\(best.name.lowercased())", "\(best.count)"),
                    Double(best.count) * 0.5, "slag-\(row.rawValue)-\(best.name)")
            }
        }
        return result
    }

    /// The kind of unforced error `player` made most, when it happened at least twice
    static func mostCommonErrorKind(in game: Game, madeBy player: Player) -> ErrorKindCount? {
        let counts = game.errorKindCounts(madeBy: player)
        var best: ErrorKind? = nil
        var most = 1
        for kind in ErrorKind.allCases {
            let count = counts[kind] ?? 0
            if count > most {
                most = count
                best = kind
            }
        }
        guard let best else { return nil }
        return ErrorKindCount(kind: best, count: most)
    }

    static func errorKindTip(_ kind: ErrorKind, count: Int) -> String {
        switch kind {
        case .down: return L10n.text("%@× in de tin: mik iets hoger boven de tin.", "\(count)")
        case .outOfCourt: return L10n.text("%@× out: minder risico, houd de bal onder de outlijn.", "\(count)")
        case .service: return L10n.text("%@ servicefouten: neem je tijd en speel een veilige service.", "\(count)")
        case .viaFloor: return L10n.text("%@× via de grond: kom laag en blijf achter de bal.", "\(count)")
        }
    }

    /// The shot that won most points (winners and forced errors) in a row,
    /// with at least 3; a volley counts as the same shot
    static func bestShot(in game: Game, for player: Player, row: CourtRow) -> ShotCount? {
        var best: ShotCount? = nil
        for shot in ShotType.allCases {
            var count = 0
            for point in game.attackingPoints(by: player) where point.shotType == shot && point.zone?.row == row {
                count += 1
            }
            if count >= minimumPoints && count > (best?.count ?? 0) {
                best = ShotCount(shot: shot, count: count)
            }
        }
        return best
    }

    /// "1", "1 en 2", "1, 2 en 3"
    static func list(_ numbers: [Int]) -> String {
        var texts: [String] = []
        for number in numbers {
            texts.append("\(number)")
        }
        if texts.count <= 1 { return texts.first ?? "" }
        return texts.dropLast().joined(separator: ", ") + " " + L10n.text("en") + " " + texts[texts.count - 1]
    }

    static func tempoCandidate(in game: Game, for player: Player) -> AdviceCandidate? {
        guard game.points.count >= 4 else { return nil }
        if let shortWin = game.shortRallyWinPercentage(for: player),
           let longWin = game.longRallyWinPercentage(for: player),
           abs(shortWin - longWin) > 15 {
            // The chance: the points lost in the kind of rally the player is weaker in.
            // Over the timed rallies only, like the percentages (an untimed first
            // rally has duration 0 and would pull the median down).
            let timed = game.timedPoints
            var durations: [TimeInterval] = []
            for point in timed {
                durations.append(point.duration)
            }
            durations.sort()
            let median = durations[durations.count / 2]
            var lostLong = 0
            var lostShort = 0
            for point in timed where point.scorer != player {
                if point.duration >= median { lostLong += 1 } else { lostShort += 1 }
            }
            if shortWin > longWin {
                return AdviceCandidate(item: AdviceItem(topic: AdviceTopic.speedUp, tone: AdviceTone.success,
                                                        text: L10n.text("Versnel het spel: je wint %@% van de korte rally's en %@% van de lange.", "\(Int(shortWin))", "\(Int(longWin))")),
                                       potential: Double(lostLong), key: "tempo-sneller", order: 0)
            }
            return AdviceCandidate(item: AdviceItem(topic: AdviceTopic.slowDown, tone: AdviceTone.success,
                                                    text: L10n.text("Vertraag het spel: je wint %@% van de lange rally's en %@% van de korte.", "\(Int(longWin))", "\(Int(shortWin))")),
                                   potential: Double(lostShort), key: "tempo-trager", order: 0)
        }
        if let won = game.averageDurationWon(by: player), let lost = game.averageDurationLost(by: player), abs(won - lost) > 3 {
            let durations = L10n.text("je gewonnen punten duren gemiddeld %@, je verloren punten %@.", "\(formatDuration(won))", "\(formatDuration(lost))")
            let potential = Double(game.pointsLost(by: player).count) / 2.0
            if won < lost {
                return AdviceCandidate(item: AdviceItem(topic: AdviceTopic.speedUp, tone: AdviceTone.info, text: L10n.text("Versnel het spel: ") + durations),
                                       potential: potential, key: "tempo-sneller", order: 0)
            }
            return AdviceCandidate(item: AdviceItem(topic: AdviceTopic.slowDown, tone: AdviceTone.info, text: L10n.text("Vertraag het spel: ") + durations),
                                   potential: potential, key: "tempo-trager", order: 0)
        }
        return nil
    }

    /// "12s" below a minute, "1:05" from a minute
    static func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds.rounded()))s"
        }
        let total = Int(seconds)
        let secs = total % 60
        return "\(total / 60):\(secs < 10 ? "0" : "")\(secs)"
    }
}

/// A kind of unforced error and how often it happened (a struct, not a tuple:
/// tuple labels are fragile in Skip's Kotlin, see docs/android-port.md)
struct ErrorKindCount {
    let kind: ErrorKind
    let count: Int
}
