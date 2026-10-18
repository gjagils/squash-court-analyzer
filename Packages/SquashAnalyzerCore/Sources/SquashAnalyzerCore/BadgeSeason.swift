import Foundation

/// The badge reset at the production release (3.0): from `start` on, everyone
/// collects badges from zero. Nothing is deleted; awards earned before `start`
/// are kept (and still travel in card links and backups) but no longer show
/// or count, matches played before it earn nothing and count for no career
/// badge, and every card that had badges before it gets the badge Pionier.
/// The same fixed date on every device, so shared cards stay alike.
/// See docs/wijzigingen-builds.md (backlog, 18 October 2026).
public enum BadgeSeason {
    /// The first moment that counts; nil while the release date is not fixed
    /// (then nothing changes). Friday 23 October 2026, 00:00 in the
    /// Netherlands (provisional, Gerd-Jan, 18 October 2026); the same seconds
    /// as SEASON_START in website/kaart/index.html.
    public static let start: Date? = Date(timeIntervalSince1970: 1_792_706_400)

    /// The fixed "match" Pionier is stored under, so every device that grants
    /// it to a card makes the same award id
    public static let pioneerMatchId = UUID(uuidString: "5A1E0000-0000-4000-8000-000000000300")!

    /// The start once it has passed; nil before that (or when there is no date)
    public static func activeStart(start: Date? = BadgeSeason.start, now: Date = Date()) -> Date? {
        guard let start = start, now >= start else { return nil }
        return start
    }

    /// Whether something dated `date` counts for badges: always, until the
    /// start has passed; from then on only when it is not from before the start
    public static func counts(_ date: Date, start: Date? = BadgeSeason.start, now: Date = Date()) -> Bool {
        guard let start = activeStart(start: start, now: now) else { return true }
        return date >= start
    }

    /// Whether an award shows and counts: not deleted and not from before the start
    public static func shows(earnedAt: Date, deletedAt: Date?, start: Date? = BadgeSeason.start, now: Date = Date()) -> Bool {
        deletedAt == nil && counts(earnedAt, start: start, now: now)
    }

    /// The cards among `awards` that earn Pionier: an active award from before
    /// the start (Pionier itself aside). Empty until the start has passed.
    public static func pioneerCards(among awards: [AwardValue], start: Date? = BadgeSeason.start, now: Date = Date()) -> [UUID] {
        guard let start = activeStart(start: start, now: now) else { return [] }
        var cards: [UUID] = []
        for award in awards where award.deletedAt == nil && award.badge != BadgeKind.pioneer && award.earnedAt < start {
            if !cards.contains(award.cardId) { cards.append(award.cardId) }
        }
        return cards
    }

    /// Pionier for one card, the same record on every device
    public static func pioneerAward(cardId: UUID, awardedBy: String, start: Date) -> AwardValue {
        AwardValue(cardId: cardId, badge: BadgeKind.pioneer, matchId: pioneerMatchId, earnedAt: start,
                   opponentName: "", awardedBy: awardedBy, deletedAt: nil)
    }
}
