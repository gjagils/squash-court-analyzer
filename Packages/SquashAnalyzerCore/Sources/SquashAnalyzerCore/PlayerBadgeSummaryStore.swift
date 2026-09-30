import Foundation

/// Read-only view onto a player's earned badges, for the "Spelers" list and
/// a player's badge screen. Android implements this over `BadgeAwardStore`;
/// this is deliberately not a full award CRUD protocol.
public protocol PlayerBadgeSummaryStore: Sendable {
    func badges(forPlayer playerId: String) async throws -> [BadgeKind]

    /// The player's card as a shareable snapshot: every award on their card,
    /// deletions included, oldest first, like iOS' `CardStore.snapshot(for:)`.
    /// Nil when the player no longer exists.
    func cardSnapshot(forPlayer playerId: String) async throws -> CardSnapshot?
}
