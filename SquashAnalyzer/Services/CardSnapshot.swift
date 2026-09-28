import Foundation
import SwiftData
import SquashAnalyzerCore

// `AwardValue` and `CardSnapshot` (the card link format and the deterministic
// award id) live in SquashAnalyzerCore, so iOS and Android read and write the
// exact same links. What stays here is the SwiftData side.

extension AwardValue {
    init?(_ award: SavedBadgeAward) {
        guard let badge = award.badgeKind else { return nil }
        self.init(cardId: award.cardId, badge: badge, matchId: award.matchId, earnedAt: award.earnedAt,
                  opponentName: award.opponentName, awardedBy: award.awardedBy, deletedAt: award.deletedAt)
    }
}

enum CardLinkError: LocalizedError {
    case noICloud
    case notShared

    var errorDescription: String? {
        switch self {
        case .noICloud: return "Log in bij iCloud om spelerskaarten te delen."
        case .notShared: return "Deze kaart is (nog) niet gedeeld."
        }
    }
}

// MARK: - Merging cards into the store

/// Store operations shared by snapshot links and CloudKit: merge awards, link a
/// local player to a card, and read a card back out.
@MainActor
struct CardStore {
    let context: ModelContext

    /// Inserts unknown awards and applies deletions (a deletion always wins).
    /// Returns the awards that changed, so they can be sent on to a shared card.
    @discardableResult
    func merge(_ values: [AwardValue]) throws -> [SavedBadgeAward] {
        var changed: [SavedBadgeAward] = []
        for value in values {
            let id = value.id
            var descriptor = FetchDescriptor<SavedBadgeAward>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first {
                if existing.deletedAt == nil, let deletedAt = value.deletedAt {
                    existing.deletedAt = deletedAt
                    changed.append(existing)
                }
            } else {
                let award = SavedBadgeAward(cardId: value.cardId, badge: value.badge, matchId: value.matchId,
                                            earnedAt: value.earnedAt, opponentName: value.opponentName,
                                            awardedBy: value.awardedBy)
                award.deletedAt = value.deletedAt
                context.insert(award)
                changed.append(award)
            }
        }
        return changed
    }

    /// What a merge would add: new badges and new deletions
    func preview(_ values: [AwardValue]) throws -> (new: Int, deleted: Int) {
        var new = 0, deleted = 0
        for value in values {
            let id = value.id
            var descriptor = FetchDescriptor<SavedBadgeAward>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first {
                if existing.deletedAt == nil, value.deletedAt != nil { deleted += 1 }
            } else if value.deletedAt == nil {
                new += 1
            }
        }
        return (new, deleted)
    }

    /// Links a local player (or a new one) to a card. The player's own badges
    /// move onto the card, so nothing earned before the link is lost.
    @discardableResult
    func link(cardId: UUID, name: String, to existing: SavedPlayer?) throws -> SavedPlayer {
        let player: SavedPlayer
        if let existing {
            player = existing
        } else {
            player = SavedPlayer(name: name)
            context.insert(player)
        }
        let oldCard = player.badgeCardId
        if oldCard != cardId {
            let moved = try awards(onCard: oldCard)
            try merge(moved.compactMap(AwardValue.init).map { $0.onCard(cardId) })
            moved.forEach(context.delete)
            player.cardId = cardId == player.id ? nil : cardId
        }
        return player
    }

    func player(forCard cardId: UUID) throws -> SavedPlayer? {
        try context.fetch(FetchDescriptor<SavedPlayer>()).first { $0.badgeCardId == cardId }
    }

    func awards(onCard cardId: UUID) throws -> [SavedBadgeAward] {
        try context.fetch(FetchDescriptor<SavedBadgeAward>(predicate: #Predicate { $0.cardId == cardId }))
    }

    func snapshot(for player: SavedPlayer) throws -> CardSnapshot {
        let cardId = player.badgeCardId
        let values = try awards(onCard: cardId)
            .sorted { $0.earnedAt < $1.earnedAt }
            .compactMap(AwardValue.init)
        return CardSnapshot(cardId: cardId, name: player.name, awards: values)
    }

    func card(_ cardId: UUID) throws -> SavedPlayerCard? {
        var descriptor = FetchDescriptor<SavedPlayerCard>(predicate: #Predicate { $0.cardId == cardId })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
