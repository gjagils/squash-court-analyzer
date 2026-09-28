import Foundation
import SwiftData
import SquashAnalyzerCore

/// One moment a player earned a badge: at most one per player card, badge and
/// match. The id is derived from those three, so every device that computes the
/// award for the same match produces the same record. Deleting only sets
/// `deletedAt` (never cleared again), so a recomputation does not bring the
/// badge back, while a new match can earn it again.
@Model
final class SavedBadgeAward {
    var id: UUID
    /// `SavedPlayer.badgeCardId` of the player who earned it
    var cardId: UUID
    /// `BadgeKind` raw value
    var badge: String
    /// `SavedMatch.id` or `SavedRefereeMatch.matchId`
    var matchId: UUID
    var earnedAt: Date
    /// Opponent in that match, for the list of earning moments
    var opponentName: String
    /// Install that awarded it (see `BadgeAwarder.installId`)
    var awardedBy: String
    var deletedAt: Date? = nil
    /// Encoded CloudKit system fields once the award was saved to a shared card
    var cloudSystemFields: Data? = nil

    init(cardId: UUID, badge: BadgeKind, matchId: UUID, earnedAt: Date, opponentName: String, awardedBy: String) {
        self.id = Self.awardId(cardId: cardId, badge: badge, matchId: matchId)
        self.cardId = cardId
        self.badge = badge.rawValue
        self.matchId = matchId
        self.earnedAt = earnedAt
        self.opponentName = opponentName
        self.awardedBy = awardedBy
    }

    var badgeKind: BadgeKind? { BadgeKind(rawValue: badge) }
    var isActive: Bool { deletedAt == nil }

    /// Deterministic id, shared with Android (see `AwardValue.awardId` in SquashAnalyzerCore)
    static func awardId(cardId: UUID, badge: BadgeKind, matchId: UUID) -> UUID {
        AwardValue.awardId(cardId: cardId, badge: badge, matchId: matchId)
    }
}
