import Foundation

// The coach dashboard's local advice ("Tactisch advies"), shared by iOS and
// Android so both give the same advice for the same game. Moved out of iOS'
// CoachDashboardView; the rules and the wording are unchanged. The platforms
// only pick an icon per topic.

public enum AdviceTone: Equatable, Sendable {
    case success, warning, info
}

/// What an advice line is about; the platform shows an icon for it
public enum AdviceTopic: Equatable, Sendable {
    case speedUp, slowDown
    case ownErrors, hurry, forcedErrors, letsAgainst
    case opponentErrors, opponentServicePoints, ownServicePoints, letsFor
    case avoidZone, playTo, bestShot
}

public struct AdviceItem: Equatable, Sendable {
    public let topic: AdviceTopic
    public let tone: AdviceTone
    public let text: String

    public init(topic: AdviceTopic, tone: AdviceTone, text: String) {
        self.topic = topic
        self.tone = tone
        self.text = text
    }
}

public struct ShotCount: Equatable, Sendable {
    public let shot: ShotType
    /// Played out of the air ("Uit de lucht"); always false for the old Volley shot
    public let isVolley: Bool
    public let count: Int

    public init(shot: ShotType, isVolley: Bool = false, count: Int) {
        self.shot = shot
        self.isVolley = isVolley
        self.count = count
    }

    /// "Drop", "Volley drop" or "Volley (oud)"
    public var name: String { shot.displayName(isVolley: isVolley) }
}

public enum CoachAdvice {
    /// "12s" below a minute, "1:05" from a minute
    public static func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds.rounded()))s"
        }
        let total = Int(seconds)
        let secs = total % 60
        return "\(total / 60):\(secs < 10 ? "0" : "")\(secs)"
    }

    /// Faster or slower: short vs long rallies won, or else the average
    /// length of won vs lost points. Nil below 4 points or without a clear
    /// difference.
    public static func tempo(in game: Game, for player: Player) -> AdviceItem? {
        guard game.points.count >= 4 else { return nil }
        if let shortWin = game.shortRallyWinPercentage(for: player),
           let longWin = game.longRallyWinPercentage(for: player),
           abs(shortWin - longWin) > 15 {
            if shortWin > longWin {
                return AdviceItem(topic: .speedUp, tone: .success,
                                  text: "Versnel het spel! Je wint \(Int(shortWin))% van korte rally's vs \(Int(longWin))% van lange")
            }
            return AdviceItem(topic: .slowDown, tone: .success,
                              text: "Vertraag het spel! Je wint \(Int(longWin))% van lange rally's vs \(Int(shortWin))% van korte")
        }
        if let won = game.averageDurationWon(by: player), let lost = game.averageDurationLost(by: player), abs(won - lost) > 3 {
            let durations = "Je gewonnen punten duren gem. \(formatDuration(won)), verloren \(formatDuration(lost))"
            if won < lost {
                return AdviceItem(topic: .speedUp, tone: .info, text: "Versnel het spel! \(durations)")
            }
            return AdviceItem(topic: .slowDown, tone: .info, text: "Vertraag het spel! \(durations)")
        }
        return nil
    }

    /// All advice lines for `player`, in the dashboard's order
    public static func local(in game: Game, for player: Player) -> [AdviceItem] {
        let opponent = player.opponent
        let opponentName = game.name(for: opponent)
        var result: [AdviceItem] = []
        if let tempo = tempo(in: game, for: player) {
            result.append(tempo)
        }

        // The player's own unforced errors are points the opponent scored on them
        let ownErrors = game.unforcedErrors(by: opponent).count
        let errorRate = game.points.isEmpty ? 0.0 : Double(ownErrors) / Double(game.points.count)
        if ownErrors >= 3 {
            result.append(AdviceItem(topic: .ownErrors, tone: .warning,
                                     text: "\(ownErrors) eigen fouten - focus op concentratie en rustig spelen"))
        } else if ownErrors >= 2 && errorRate > 0.25 {
            result.append(AdviceItem(topic: .hurry, tone: .warning, text: "Minder haast - neem meer tijd voor je slagen"))
        }

        let forcedAgainst = game.forcedErrors(by: opponent).count
        if forcedAgainst >= 3 {
            result.append(AdviceItem(topic: .forcedErrors, tone: .warning,
                                     text: "\(forcedAgainst) forced errors - racket eerder klaar voor je slag"))
        }

        let letsAgainst = game.letsRequested(by: opponent).count
        let letsFor = game.letsRequested(by: player).count
        if letsAgainst >= 2 {
            result.append(AdviceItem(topic: .letsAgainst, tone: .warning,
                                     text: "\(letsAgainst) lets tegen - beweeg sneller weg naar de T na je slag"))
        }

        let opponentErrors = game.unforcedErrors(by: player).count
        if opponentErrors >= 3 {
            result.append(AdviceItem(topic: .opponentErrors, tone: .success,
                                     text: "\(opponentName) maakt \(opponentErrors) fouten - blijf druk zetten"))
        }

        let opponentServicePoints = game.servicePoints(by: opponent).count
        if opponentServicePoints >= 2 {
            result.append(AdviceItem(topic: .opponentServicePoints, tone: .warning,
                                     text: "\(opponentName) scoort \(opponentServicePoints) servicepunten - racket vroeg omhoog bij de return"))
        }
        let ownServicePoints = game.servicePoints(by: player).count
        if ownServicePoints >= 2 {
            result.append(AdviceItem(topic: .ownServicePoints, tone: .success,
                                     text: "Je hebt \(ownServicePoints) servicepunten - je service werkt, blijf zo serveren!"))
        }

        if letsFor >= 2 && letsAgainst < 2 {
            result.append(AdviceItem(topic: .letsFor, tone: .success, text: "\(letsFor) lets mee - je beweegt goed naar de bal"))
        }

        if let zone = game.bestZone(for: opponent) {
            result.append(AdviceItem(topic: .avoidZone, tone: .warning,
                                     text: "Vermijd \(zone.rawValue) - daar is \(opponentName) sterk"))
        }
        let recommended = game.recommendedZones(against: opponent)
        if !recommended.isEmpty {
            var names: [String] = []
            for zone in recommended {
                names.append(zone.rawValue)
            }
            result.append(AdviceItem(topic: .playTo, tone: .success, text: "Speel naar: \(names.joined(separator: ", "))"))
        }
        if let shot = game.bestShotType(for: player) {
            result.append(AdviceItem(topic: .bestShot, tone: .info, text: "Je \(shot.rawValue) is effectief, blijf dit gebruiken"))
        }
        return result
    }

    /// The player's scoring shots, most first (at most `limit`). A volley
    /// counts apart from the same shot off the bounce: "Volley drop" and
    /// "Drop" are two lines.
    public static func topShots(in game: Game, for player: Player, limit: Int = 4) -> [ShotCount] {
        var counts: [ShotCount] = []
        for shot in ShotType.allCases {
            for volley in [false, true] {
                var count = 0
                for point in game.points where point.scorer == player && point.shotType == shot && point.isVolley == volley {
                    count += 1
                }
                if count > 0 {
                    counts.append(ShotCount(shot: shot, isVolley: volley, count: count))
                }
            }
        }
        counts.sort { first, second in first.count > second.count }
        return Array(counts.prefix(limit))
    }

    /// The player's volleys by shot, most first: "3 drop, 1 kill". Older
    /// "Volley" points show as "2 oud". Nil without volleys.
    public static func volleyBreakdown(in game: Game, for player: Player) -> String? {
        var parts: [ShotCount] = []
        for shot in ShotType.allCases {
            var count = 0
            for point in game.volleysWon(by: player) where point.shotType == shot {
                count += 1
            }
            if count > 0 {
                parts.append(ShotCount(shot: shot, count: count))
            }
        }
        if parts.isEmpty { return nil }
        parts.sort { first, second in first.count > second.count }
        var texts: [String] = []
        for part in parts {
            texts.append("\(part.count) \(part.shot.isLegacy ? "oud" : part.shot.rawValue.lowercased())")
        }
        return texts.joined(separator: ", ")
    }
}
