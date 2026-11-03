import Foundation

// MARK: - Voortgang naar de volgende trede (3.2)

/// How far a player is from the next tier of a career badge: "Nog 3 tot zilver".
/// Only for the badges counted over all matches with one running number:
/// Veteran (matches), Ten out of ten (wins), Centurion (points won) and Hat
/// trick (the current winning streak). Badges within one match or game have no
/// running number between matches, and Nemesis counts per opponent.
public struct BadgeProgress: Equatable, Sendable {
    /// The bronze badge of the series
    public let family: BadgeKind
    /// The tier to reach next
    public let next: BadgeKind
    /// Where the player is now
    public let current: Int
    /// How many are still needed
    public var remaining: Int { max(0, (next.threshold ?? 0) - current) }

    public init(family: BadgeKind, next: BadgeKind, current: Int) {
        self.family = family
        self.next = next
        self.current = current
    }

    /// "Nog 3 tot zilver", "Nog 1 tot brons"
    public var text: String {
        let tier = next.tier?.title.lowercased() ?? ""
        return L10n.text("Nog %@ tot %@", String(remaining), tier)
    }

    /// The families that can show progress
    public static let families: [BadgeKind] = [BadgeKind.veteran, BadgeKind.tenOutOfTen, BadgeKind.centurion, BadgeKind.hatTrick]

    /// The progress per family from the player's finished matches (as for
    /// `BadgeEngine.careerBadges`: matches before the badge reset and oefenpartijen
    /// do not count). A family whose highest tier is reached has no entry.
    public static func of(history: [BadgeEngine.CareerMatch]) -> [BadgeProgress] {
        let ordered = history.filter { entry in BadgeSeason.counts(entry.date) && !PracticeMatches.shared.contains(entry.matchId) }
            .sorted { a, b in a.date < b.date }
        var wins = 0
        var points = 0
        var streak = 0
        for entry in ordered {
            points += entry.pointsWon
            if entry.won {
                wins += 1
                streak += 1
            } else {
                streak = 0
            }
        }
        var result: [BadgeProgress] = []
        for family in families {
            let value: Int
            switch family {
            case .veteran: value = ordered.count
            case .tenOutOfTen: value = wins
            case .centurion: value = points
            default: value = streak
            }
            for kind in BadgeKind.series(of: family) {
                guard let threshold = kind.threshold, value < threshold else { continue }
                result.append(BadgeProgress(family: family, next: kind, current: value))
                break
            }
        }
        return result
    }
}
