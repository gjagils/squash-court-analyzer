import Foundation

/// One time a player earned a badge: against whom and when. Deleting it
/// (swipe on iOS, "Verwijder" on Android) marks the award deleted; the
/// deletion travels with the next shared card.
public struct BadgeMoment: Identifiable, Equatable, Sendable {
    /// The award id
    public let id: String
    public let badge: BadgeKind
    public let earnedAt: Date
    public let opponentName: String

    public init(id: String, badge: BadgeKind, earnedAt: Date, opponentName: String) {
        self.id = id
        self.badge = badge
        self.earnedAt = earnedAt
        self.opponentName = opponentName
    }
}

/// Read-only view onto a player's earned badges, for the "Spelers" list and
/// a player's badge screen (with the earning moments, which can be deleted).
/// Android implements this over `BadgeAwardStore`.
public protocol PlayerBadgeSummaryStore: Sendable {
    func badges(forPlayer playerId: String) async throws -> [BadgeKind]

    /// How many different badges each player has, in one go for the player
    /// list (instead of one `badges(forPlayer:)` per player)
    func badgeCounts(forPlayers playerIds: [String]) async throws -> [String: Int]

    /// The player's card as a shareable snapshot: every award on their card,
    /// deletions included, oldest first, like iOS' `CardStore.snapshot(for:)`.
    /// Nil when the player no longer exists.
    func cardSnapshot(forPlayer playerId: String) async throws -> CardSnapshot?

    /// Every badge the player still has, one entry per time earned, newest first
    func moments(forPlayer playerId: String) async throws -> [BadgeMoment]

    /// Marks one earned moment deleted
    func deleteMoment(_ id: String) async throws
}
