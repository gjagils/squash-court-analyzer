import Foundation
import SwiftData

/// One badge award as it travels between devices, in a snapshot link or a
/// CloudKit record.
struct AwardValue: Equatable {
    let cardId: UUID
    let badge: BadgeKind
    let matchId: UUID
    let earnedAt: Date
    let opponentName: String
    let awardedBy: String
    let deletedAt: Date?

    var id: UUID { SavedBadgeAward.awardId(cardId: cardId, badge: badge, matchId: matchId) }

    init(cardId: UUID, badge: BadgeKind, matchId: UUID, earnedAt: Date, opponentName: String, awardedBy: String, deletedAt: Date?) {
        self.cardId = cardId
        self.badge = badge
        self.matchId = matchId
        self.earnedAt = earnedAt
        self.opponentName = opponentName
        self.awardedBy = awardedBy
        self.deletedAt = deletedAt
    }

    init?(_ award: SavedBadgeAward) {
        guard let badge = award.badgeKind else { return nil }
        self.init(cardId: award.cardId, badge: badge, matchId: award.matchId, earnedAt: award.earnedAt,
                  opponentName: award.opponentName, awardedBy: award.awardedBy, deletedAt: award.deletedAt)
    }

    /// The same award on another card (when a player is linked to a shared card)
    func onCard(_ cardId: UUID) -> AwardValue {
        AwardValue(cardId: cardId, badge: badge, matchId: matchId, earnedAt: earnedAt,
                   opponentName: opponentName, awardedBy: awardedBy, deletedAt: deletedAt)
    }
}

// MARK: - Snapshot link

/// A player card in a link: `https://squashanalyzer.com/kaart/#<payload>`, the
/// payload being deflated JSON in base64url. The data sits in the fragment,
/// which browsers never send to the server; the web page draws the card from it
/// and the app merges it.
struct CardSnapshot: Codable, Equatable {
    var v = 1
    /// Card id
    let c: UUID
    /// Player name
    let n: String
    /// Awards, deleted ones included so a deletion travels too
    let a: [Entry]

    struct Entry: Codable, Equatable {
        let b: String
        let m: UUID
        /// Earned at, seconds since 1970
        let t: Int
        let o: String
        let w: String
        /// Deleted at, seconds since 1970
        let d: Int?
    }

    static let webBase = "https://squashanalyzer.com/kaart/#"
    static let appBase = "squashanalyzer://kaart#"

    init(cardId: UUID, name: String, awards: [AwardValue]) {
        c = cardId
        n = name
        a = awards.map {
            Entry(b: $0.badge.rawValue, m: $0.matchId, t: Int($0.earnedAt.timeIntervalSince1970),
                  o: $0.opponentName, w: $0.awardedBy, d: $0.deletedAt.map { Int($0.timeIntervalSince1970) })
        }
    }

    var cardId: UUID { c }
    var name: String { n }

    var awards: [AwardValue] {
        a.compactMap { entry in
            guard let badge = BadgeKind(rawValue: entry.b) else { return nil }
            return AwardValue(cardId: c, badge: badge, matchId: entry.m,
                              earnedAt: Date(timeIntervalSince1970: TimeInterval(entry.t)),
                              opponentName: entry.o, awardedBy: entry.w,
                              deletedAt: entry.d.map { Date(timeIntervalSince1970: TimeInterval($0)) })
        }
    }

    func payload() throws -> String {
        let json = try JSONEncoder().encode(self)
        let deflated = try (json as NSData).compressed(using: .zlib) as Data
        return deflated.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func webURL() throws -> URL {
        URL(string: Self.webBase + (try payload()))!
    }

    init(payload: String) throws {
        var base64 = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let deflated = Data(base64Encoded: base64) else { throw CardLinkError.unreadable }
        let json = try (deflated as NSData).decompressed(using: .zlib) as Data
        self = try JSONDecoder().decode(CardSnapshot.self, from: json)
    }

    /// Reads a card link from the website or the app's own scheme; nil for any other URL
    init?(url: URL) {
        let isWeb = ["squashanalyzer.com", "www.squashanalyzer.com"].contains(url.host ?? "") && url.path.hasPrefix("/kaart")
        let isApp = url.scheme == "squashanalyzer" && url.host == "kaart"
        guard isWeb || isApp, let fragment = url.fragment, !fragment.isEmpty,
              let snapshot = try? CardSnapshot(payload: fragment) else { return nil }
        self = snapshot
    }
}

enum CardLinkError: LocalizedError {
    case unreadable
    case noICloud
    case notShared

    var errorDescription: String? {
        switch self {
        case .unreadable: return "Deze kaartlink kan niet worden gelezen."
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
