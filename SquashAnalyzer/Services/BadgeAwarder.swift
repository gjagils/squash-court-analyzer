import Foundation
import SwiftData

/// Keeps the stored badge awards of one match in line with its rallies. Called
/// on every save of a match, so an undone rally also takes back a badge that was
/// not really earned; a badge the user deleted stays deleted.
@MainActor
struct BadgeAwarder {
    let context: ModelContext
    var engine = BadgeEngine()

    /// Identifies this install as the awarding coach (for "delete the badges you awarded")
    static var installId: String {
        let key = "badgeInstallId"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    /// Inserts missing awards and removes active ones the rallies no longer
    /// support. Does not save; the caller saves together with the match.
    func syncAwards(matchId: UUID,
                    playerIds: [Player: UUID],
                    playerNames: [Player: String],
                    input: BadgeMatchInput,
                    earnedAt: Date = Date()) throws {
        let earned = engine.badges(for: input)
        var expected: [UUID: (cardId: UUID, badge: BadgeKind, player: Player)] = [:]
        for (player, playerId) in playerIds {
            guard let cardId = try cardId(forPlayer: playerId) else { continue }
            var badges = earned[player] ?? []
            if input.matchWinner != nil {
                badges.formUnion(engine.careerBadges(in: matchId, history: try history(of: playerId),
                                                     earnedElsewhere: try onceBadges(onCard: cardId, except: matchId)))
            }
            for badge in badges {
                expected[SavedBadgeAward.awardId(cardId: cardId, badge: badge, matchId: matchId)] = (cardId, badge, player)
            }
        }

        let existing = try awards(forMatch: matchId)
        let existingIds = Set(existing.map(\.id))
        var removed: [(id: UUID, cardId: UUID)] = []
        for award in existing where expected[award.id] == nil && award.isActive {
            removed.append((award.id, award.cardId))
            context.delete(award)
        }
        var inserted: [SavedBadgeAward] = []
        for (id, value) in expected where !existingIds.contains(id) {
            let award = SavedBadgeAward(
                cardId: value.cardId,
                badge: value.badge,
                matchId: matchId,
                earnedAt: earnedAt,
                opponentName: playerNames[value.player.opponent] ?? "",
                awardedBy: Self.installId
            )
            context.insert(award)
            inserted.append(award)
        }
        CardSync.shared.awardsRemoved(removed)
        CardSync.shared.awardsChanged(inserted)
    }

    /// A discarded match was never really played: its awards go completely.
    func removeAwards(forMatch matchId: UUID) throws {
        let awards = try awards(forMatch: matchId)
        CardSync.shared.awardsRemoved(awards.map { ($0.id, $0.cardId) })
        awards.forEach(context.delete)
    }

    /// A deleted match keeps its awards as deleted, so they cannot come back.
    func markAwardsDeleted(forMatch matchId: UUID, at date: Date = Date()) throws {
        let deleted = try awards(forMatch: matchId).filter(\.isActive)
        deleted.forEach { $0.deletedAt = date }
        CardSync.shared.awardsChanged(deleted)
    }

    private func awards(forMatch matchId: UUID) throws -> [SavedBadgeAward] {
        try context.fetch(FetchDescriptor<SavedBadgeAward>(predicate: #Predicate { $0.matchId == matchId }))
    }

    /// Finished matches of a player on this device (coach and referee), for the career badges
    func history(of playerId: UUID) throws -> [BadgeEngine.CareerMatch] {
        var matches: [BadgeEngine.CareerMatch] = []
        for match in try context.fetch(FetchDescriptor<SavedMatch>()) {
            guard let slot: Player = match.player1Id == playerId ? .player1 : (match.player2Id == playerId ? .player2 : nil),
                  let winner = match.matchWinner else { continue }
            let points = match.games.reduce(0) { $0 + (slot == .player1 ? $1.player1Score : $1.player2Score) }
            let opponent = slot == .player1 ? (match.player2Id?.uuidString ?? match.player2Name) : (match.player1Id?.uuidString ?? match.player1Name)
            matches.append(.init(matchId: match.id, date: match.savedAt, won: winner == slot, pointsWon: points,
                                 opponentKey: opponent.lowercased()))
        }
        for match in try context.fetch(FetchDescriptor<SavedRefereeMatch>()) {
            guard let matchId = match.matchId,
                  let slot: Player = match.player1Id == playerId ? .player1 : (match.player2Id == playerId ? .player2 : nil),
                  match.winnerName != nil else { continue }
            let winner: Player = match.player1GamesWon >= match.gamesToWin ? .player1 : .player2
            let points = match.gameResults.reduce(0) { $0 + (slot == .player1 ? $1.player1Score : $1.player2Score) }
            let opponent = slot == .player1 ? (match.player2Id?.uuidString ?? match.player2Name) : (match.player1Id?.uuidString ?? match.player1Name)
            matches.append(.init(matchId: matchId, date: match.savedAt, won: winner == slot, pointsWon: points,
                                 opponentKey: opponent.lowercased()))
        }
        return matches
    }

    /// Once-only badges the card already has from another match
    private func onceBadges(onCard cardId: UUID, except matchId: UUID) throws -> Set<BadgeKind> {
        let awards = try context.fetch(FetchDescriptor<SavedBadgeAward>(predicate: #Predicate { $0.cardId == cardId }))
        return Set(awards.filter { $0.matchId != matchId && $0.isActive }.compactMap(\.badgeKind).filter(\.isOnce))
    }

    private func cardId(forPlayer playerId: UUID) throws -> UUID? {
        var descriptor = FetchDescriptor<SavedPlayer>(predicate: #Predicate { $0.id == playerId })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.badgeCardId
    }
}

extension Match {
    var playerIds: [Player: UUID] {
        var ids: [Player: UUID] = [:]
        ids[.player1] = player1Id
        ids[.player2] = player2Id
        return ids
    }
}

extension RefereeMatch {
    var playerIds: [Player: UUID] {
        var ids: [Player: UUID] = [:]
        ids[.player1] = player1Id
        ids[.player2] = player2Id
        return ids
    }
}
