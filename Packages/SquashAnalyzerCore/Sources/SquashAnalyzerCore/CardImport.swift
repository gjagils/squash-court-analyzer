import Foundation
import Observation

// Receiving a card link (https://squashanalyzer.com/kaart/#… or
// squashanalyzer://kaart#…) on Android. iOS has its own SwiftData-backed
// version of this (`CardStore`, `CardImportSheet`); the rules are the same:
// link the card to a local player (or a new one), then merge its awards, where
// a deletion always wins.

/// A local player the card can be linked to
public struct CardImportPlayer: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// What importing a card would do, for the import screen
public struct CardImportPreview: Equatable, Sendable {
    /// Badges on the card that are not deleted
    public let activeBadges: Int
    /// Badges this device does not have yet
    public let newBadges: Int
    /// Badges this device has that the card deleted
    public let deletedBadges: Int
    /// The player already linked to this card, if any: importing updates them
    public let linkedPlayer: CardImportPlayer?
    /// All local players, for "Koppel aan"
    public let players: [CardImportPlayer]

    public init(activeBadges: Int, newBadges: Int, deletedBadges: Int,
                linkedPlayer: CardImportPlayer?, players: [CardImportPlayer]) {
        self.activeBadges = activeBadges
        self.newBadges = newBadges
        self.deletedBadges = deletedBadges
        self.linkedPlayer = linkedPlayer
        self.players = players
    }

    /// Same wording as iOS' `CardImportSheet`
    public var summary: String {
        var parts = [activeBadges == 1 ? "1 badge op de kaart" : "\(activeBadges) badges op de kaart"]
        if newBadges > 0 { parts.append(newBadges == 1 ? "1 nieuw voor jou" : "\(newBadges) nieuw voor jou") }
        if deletedBadges > 0 { parts.append("\(deletedBadges) verwijderd") }
        if linkedPlayer != nil && newBadges == 0 && deletedBadges == 0 { parts.append("je bent al bij") }
        return parts.joined(separator: " · ")
    }
}

/// Storage side of importing a card. Android implements this over Room in
/// `BadgeAwardStore`.
public protocol CardImportStore: Sendable {
    func importPreview(_ snapshot: CardSnapshot) async throws -> CardImportPreview

    /// Links the card to `playerId`, or to a new player named after the card
    /// when nil, and merges the card's awards. The player's own awards move
    /// onto the card first, so nothing earned before the link is lost.
    func importCard(_ snapshot: CardSnapshot, toPlayer playerId: String?) async throws
}

/// The card link that was opened and still has to be imported. The platform
/// hands links in with `receive(_:)`; the import screen shows while
/// `pending` is set.
@Observable
public final class CardInbox {
    public var pending: CardSnapshot?
    /// An invitation to a live team match (`squashanalyzer.com/team/#code`)
    public var pendingTeam: TeamInvite?
    /// Goes up after every finished import, so open screens can reload
    public private(set) var importCount = 0

    public init() {
    }

    /// The pending card was imported: close the import screen and let open screens reload
    public func finishImport() {
        pending = nil
        importCount += 1
    }

    /// Takes a link from outside the app. Returns false (and changes nothing)
    /// for anything that is not a readable card link.
    @discardableResult
    public func receive(_ link: String) -> Bool {
        if let invite = CardInbox.invite(from: link) {
            pendingTeam = invite
            return true
        }
        guard let snapshot = CardInbox.snapshot(from: link) else { return false }
        pending = snapshot
        return true
    }

    /// A team invitation in a link (not a card link), without touching the inbox.
    /// Only `squashanalyzer.com/team` or `/team/` (with the code in the fragment)
    /// and `squashanalyzer://team`: a team zip link under `/teams/` is not an
    /// invitation, and must stay a plain download.
    public static func invite(from link: String) -> TeamInvite? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("squashanalyzer://team") { return TeamInvite.parse(trimmed) }
        guard let url = URL(string: trimmed), url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(), host == "squashanalyzer.com" || host == "www.squashanalyzer.com" else { return nil }
        let path = url.path
        if path != "/team" && path != "/team/" { return nil }
        return TeamInvite.parse(trimmed)
    }

    public func acceptTeam(_ invite: TeamInvite) {
        pendingTeam = invite
    }

    /// Decodes a link without touching the inbox, so Android can do it off the
    /// main thread and hand the result to `accept` afterwards
    public static func snapshot(from link: String) -> CardSnapshot? {
        guard let url = URL(string: link) else { return nil }
        return CardSnapshot(url: url)
    }

    public func accept(_ snapshot: CardSnapshot) {
        pending = snapshot
    }
}
