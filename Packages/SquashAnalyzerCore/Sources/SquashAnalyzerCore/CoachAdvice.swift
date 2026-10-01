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
    case avoidZone, bestShot
    /// Where the player wins, loses or errs (row or side)
    case wonArea, lostArea, errorArea
    /// Where the opponent errs: a chance
    case opening
    case volleys, opponentVolleys
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

    /// The most advice lines the dashboard shows
    public static let maximumItems = 5

    /// Faster or slower: short vs long rallies won, or else the average
    /// length of won vs lost points. Nil below 4 points or without a clear
    /// difference.
    public static func tempo(in game: Game, for player: Player) -> AdviceItem? {
        tempoCandidate(in: game, for: player)?.item
    }

    /// The advice for `player` in `game`, at most five lines, the ones with
    /// the most to gain first: points lost or chances, counted in points.
    /// With the match, a finding that also showed in an earlier game is
    /// called a pattern ("Net als in game 1.").
    public static func local(in game: Game, for player: Player, match: Match? = nil) -> [AdviceItem] {
        var candidates = AdviceRules.candidates(in: game, for: player)

        var earlier: [Game] = []
        var numbers: [Int] = []
        if let match {
            for (index, other) in match.games.enumerated() {
                if other === game { break }
                earlier.append(other)
                numbers.append(match.gameNumber(at: index))
            }
        }
        if !earlier.isEmpty {
            var updated: [AdviceCandidate] = []
            for candidate in candidates {
                var seenIn: [Int] = []
                var extra = 0.0
                for (index, other) in earlier.enumerated() {
                    for previous in AdviceRules.candidates(in: other, for: player) where previous.key == candidate.key {
                        seenIn.append(numbers[index])
                        extra += previous.potential / 2.0
                    }
                }
                if seenIn.isEmpty {
                    updated.append(candidate)
                } else {
                    let text = candidate.item.text + " Net als in game " + AdviceRules.list(seenIn) + "."
                    updated.append(AdviceCandidate(item: AdviceItem(topic: candidate.item.topic, tone: candidate.item.tone, text: text),
                                                   potential: candidate.potential + extra, key: candidate.key, order: candidate.order))
                }
            }
            candidates = updated
        }

        candidates.sort { first, second in
            if first.potential != second.potential { return first.potential > second.potential }
            let firstWarns = first.item.tone == AdviceTone.warning
            let secondWarns = second.item.tone == AdviceTone.warning
            if firstWarns != secondWarns { return firstWarns }
            return first.order < second.order
        }
        var result: [AdviceItem] = []
        for candidate in candidates.prefix(maximumItems) {
            result.append(candidate.item)
        }
        return result
    }

    static func tempoCandidate(in game: Game, for player: Player) -> AdviceCandidate? {
        guard game.points.count >= 4 else { return nil }
        if let shortWin = game.shortRallyWinPercentage(for: player),
           let longWin = game.longRallyWinPercentage(for: player),
           abs(shortWin - longWin) > 15 {
            // The chance: the points lost in the kind of rally the player is weaker in
            var durations: [TimeInterval] = []
            for point in game.points {
                durations.append(point.duration)
            }
            durations.sort()
            let median = durations[durations.count / 2]
            var lostLong = 0
            var lostShort = 0
            for point in game.points where point.scorer != player {
                if point.duration >= median { lostLong += 1 } else { lostShort += 1 }
            }
            if shortWin > longWin {
                return AdviceCandidate(item: AdviceItem(topic: AdviceTopic.speedUp, tone: AdviceTone.success,
                                                        text: "Versnel het spel: je wint \(Int(shortWin))% van de korte rally's en \(Int(longWin))% van de lange."),
                                       potential: Double(lostLong), key: "tempo-sneller", order: 0)
            }
            return AdviceCandidate(item: AdviceItem(topic: AdviceTopic.slowDown, tone: AdviceTone.success,
                                                    text: "Vertraag het spel: je wint \(Int(longWin))% van de lange rally's en \(Int(shortWin))% van de korte."),
                                   potential: Double(lostShort), key: "tempo-trager", order: 0)
        }
        if let won = game.averageDurationWon(by: player), let lost = game.averageDurationLost(by: player), abs(won - lost) > 3 {
            let durations = "je gewonnen punten duren gemiddeld \(formatDuration(won)), je verloren punten \(formatDuration(lost))."
            let potential = Double(game.pointsLost(by: player).count) / 2.0
            if won < lost {
                return AdviceCandidate(item: AdviceItem(topic: AdviceTopic.speedUp, tone: AdviceTone.info, text: "Versnel het spel: " + durations),
                                       potential: potential, key: "tempo-sneller", order: 0)
            }
            return AdviceCandidate(item: AdviceItem(topic: AdviceTopic.slowDown, tone: AdviceTone.info, text: "Vertraag het spel: " + durations),
                                   potential: potential, key: "tempo-trager", order: 0)
        }
        return nil
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
