import Foundation

// 4.0, without a player code (Gerd-Jan, 1 November 2026): a player in Spelers
// is linked to an SBN player, and a finished match goes to that SBN player.
// A teammate entered by hand ("Gerd Lasso") goes as "this name in my team":
// teammates see it and claim it with "dat ben ik", and this phone learns the
// link from the server (`PlayerAccount.learnLinks`).

/// Which player in Spelers is which SBN player: player id → SBN player path
/// ("/league/<uuid>/player/<n>"). In the settings, like `TeamRoster`, so no
/// SwiftData or Room migration.
public enum PlayerSBNLinks {
    public static let storageKey = "playerSbnLinks"

    public static func all(in defaults: UserDefaults = UserDefaults.standard) -> [String: String] {
        guard let text = defaults.string(forKey: PlayerSBNLinks.storageKey), let data = text.data(using: String.Encoding.utf8),
              let value = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return value
    }

    /// Ids compare without case: a match keeps the player's id as a UUID, and
    /// its text is upper case on iOS and may be lower case in Android's store
    public static func path(for playerId: String, in defaults: UserDefaults = UserDefaults.standard) -> String? {
        let wanted = playerId.lowercased()
        for (id, path) in all(in: defaults) where id.lowercased() == wanted { return path }
        return nil
    }

    /// Links the player (nil or empty unlinks); an SBN player belongs to one player in Spelers
    public static func set(_ path: String?, for playerId: String, in defaults: UserDefaults = UserDefaults.standard) {
        var links = all(in: defaults)
        let clean = (path ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
        if clean.isEmpty {
            links[playerId] = nil
        } else {
            for other in holders(of: clean, in: links) where other != playerId { links[other] = nil }
            links[playerId] = clean
        }
        write(links, in: defaults)
    }

    public static func replace(_ links: [String: String], in defaults: UserDefaults = UserDefaults.standard) {
        write(links, in: defaults)
    }

    /// Players in Spelers with the same name as a player of the SBN team get
    /// linked, unless they already are or the SBN player is taken. Returns how many.
    @discardableResult
    public static func fill(from sbnPlayers: [LeaguePlayer], players: [PlayerProfile],
                            in defaults: UserDefaults = UserDefaults.standard) -> Int {
        var links = all(in: defaults)
        var added = 0
        for incoming in sbnPlayers {
            if incoming.id.isEmpty || links.values.contains(incoming.id) { continue }
            for player in players where links[player.id] == nil && TeamMatch.sameTeam(player.name, incoming.name) {
                links[player.id] = incoming.id
                added += 1
                break
            }
        }
        if added > 0 { write(links, in: defaults) }
        return added
    }

    /// What teammates' claims taught this phone: a player of Spelers whose name
    /// the server knows for this team gets the SBN player. Returns how many.
    @discardableResult
    public static func learn(_ learned: [AccountLearnedLink], players: [PlayerProfile], teamKey: String?,
                             in defaults: UserDefaults = UserDefaults.standard) -> Int {
        guard let teamKey, !teamKey.isEmpty else { return 0 }
        var links = all(in: defaults)
        var added = 0
        for link in learned where link.teamKey == teamKey {
            for player in players where AccountSending.nameKey(player.name) == link.name && links[player.id] != link.sbnPath {
                for other in holders(of: link.sbnPath, in: links) { links[other] = nil }
                links[player.id] = link.sbnPath
                added += 1
            }
        }
        if added > 0 { write(links, in: defaults) }
        return added
    }

    /// The players linked to `path` (collected first: changing a dictionary while walking it fails on the JVM)
    static func holders(of path: String, in links: [String: String]) -> [String] {
        var ids: [String] = []
        for (id, linked) in links where linked == path { ids.append(id) }
        return ids
    }

    private static func write(_ links: [String: String], in defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(links) else { return }
        defaults.set(String(data: data, encoding: String.Encoding.utf8), forKey: PlayerSBNLinks.storageKey)
    }
}

/// After a match: who it goes to, and into the outbox
public enum AccountSending {
    /// The Worker's key for a name: lowercased, single spaces
    public static func nameKey(_ name: String) -> String {
        var result = ""
        var lastWasSpace = false
        for character in name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased() {
            if character == " " || character == "\t" || character == "\n" {
                if !lastWasSpace { result += " " }
                lastWasSpace = true
            } else {
                result += String(character)
                lastWasSpace = false
            }
        }
        return result
    }

    /// Mijn team as the account server knows it; nil without a team link
    public static func ownTeamKey(in defaults: UserDefaults = UserDefaults.standard) -> String? {
        let link = defaults.string(forKey: LeagueTeamStorage.linkKey) ?? ""
        guard !link.isEmpty, let parsed = try? LeagueTeamLink(link) else { return nil }
        return parsed.accountKey
    }

    /// Who a player of a match goes to: the linked SBN player, or the name in
    /// Mijn team for a teammate who is not linked yet. Nil: nobody to send to
    /// (a player chosen by hand outside the team; the shared link is for those).
    public static func recipient(playerId: String?, name: String,
                                 in defaults: UserDefaults = UserDefaults.standard) -> AccountRecipient? {
        guard let playerId, !playerId.isEmpty else { return nil }
        if let path = PlayerSBNLinks.path(for: playerId, in: defaults) { return AccountRecipient(sbnPath: path) }
        let trimmed = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let inTeam = TeamRoster.ids(in: defaults).contains { id in id.lowercased() == playerId.lowercased() }
        if !trimmed.isEmpty, inTeam, let team = ownTeamKey(in: defaults) {
            return AccountRecipient(team: team, name: trimmed)
        }
        return nil
    }

    /// Queues a finished match for both players. `upload` makes the compact
    /// form for one side (nil for an oefenpartij). The signed-in player's own
    /// side (`ownSbnPath`) goes as an own match: it counts at once. Queuing the
    /// same match again replaces the waiting copy, so calling this on every
    /// save of a finished match is fine. Returns how many were queued.
    @MainActor @discardableResult
    public static func queue(upload: (Player) -> AccountMatchUpload?, playerIds: [Player: String],
                             playerNames: [Player: String], senderName: String, ownSbnPath: String?,
                             outbox: AccountOutbox = AccountOutbox.shared,
                             in defaults: UserDefaults = UserDefaults.standard) -> Int {
        var queued = 0
        for side in [Player.player1, Player.player2] {
            guard let to = recipient(playerId: playerIds[side], name: playerNames[side] ?? "", in: defaults),
                  let match = upload(side) else { continue }
            if let ownSbnPath, !ownSbnPath.isEmpty, to.sbnPath == ownSbnPath {
                if outbox.add(match, to: nil, senderName: senderName) { queued += 1 }
            } else if outbox.add(match, to: to, senderName: senderName) {
                queued += 1
            }
        }
        return queued
    }
}

public extension AccountSending {
    /// Called by the stores when a coached match is saved finished (4.0 only):
    /// queued for its players, then sent when there is network
    @MainActor
    static func queueFinished(_ match: Match) {
        guard Features.shared.playerAccount, match.isMatchOver else { return }
        queueAndSend(upload: { side in match.accountUpload(for: side) },
                     ids: [match.player1Id, match.player2Id], names: [match.player1Name, match.player2Name])
    }

    /// The same for a match the referee kept
    @MainActor
    static func queueFinished(_ match: RefereeMatch) {
        guard Features.shared.playerAccount, match.isMatchOver else { return }
        queueAndSend(upload: { side in match.accountUpload(for: side) },
                     ids: [match.player1Id, match.player2Id], names: [match.player1Name, match.player2Name])
    }

    @MainActor
    private static func queueAndSend(upload: (Player) -> AccountMatchUpload?, ids: [UUID?], names: [String]) {
        var playerIds: [Player: String] = [:]
        if let first = ids[0] { playerIds[Player.player1] = first.uuidString }
        if let second = ids[1] { playerIds[Player.player2] = second.uuidString }
        let account = PlayerAccount.shared
        let queued = queue(upload: upload, playerIds: playerIds,
                           playerNames: [Player.player1: names[0], Player.player2: names[1]],
                           senderName: account.profile?.name ?? "", ownSbnPath: account.profile?.sbnPath)
        if queued > 0 { Task { await account.sendOutbox() } }
    }
}

/// The link "Stuur naar speler" shares: https://squashanalyzer.com/wedstrijd#<token>.
/// The token is after the #, so it never reaches the website's server logs;
/// the page hands it to the app (squashanalyzer://wedstrijd#<token>).
public enum AccountClaimLink {
    public static func url(token: String) -> String { "https://squashanalyzer.com/wedstrijd#\(token)" }

    /// The token in a link that was opened, or nil when it is not such a link
    public static func token(from link: String) -> String? {
        let text = link.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let prefixes = ["https://squashanalyzer.com/wedstrijd#", "https://www.squashanalyzer.com/wedstrijd#",
                        "https://squashanalyzer.com/wedstrijd/#", "https://www.squashanalyzer.com/wedstrijd/#",
                        "squashanalyzer://wedstrijd#"]
        for prefix in prefixes where text.lowercased().hasPrefix(prefix) {
            let token = String(text.dropFirst(prefix.count))
            if token.count < 8 || token.count > 64 { return nil }
            for character in token where !"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".contains(character) {
                return nil
            }
            return token
        }
        return nil
    }
}
