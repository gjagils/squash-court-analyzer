import Foundation

/// Which players are in your own team ("In mijn team" in Spelers). A list of
/// player ids in the settings, not a column on the player: no SwiftData or
/// Room migration, and it travels in the backup (`TeamBackup`). The selection
/// buttons of a team match offer these players first.
public enum TeamRoster {
    public static let storageKey = "teamPlayerIds"

    /// The ids in a stored value ("id1,id2"), without empties and duplicates
    public static func parse(_ raw: String) -> [String] {
        var ids: [String] = []
        for part in raw.components(separatedBy: ",") {
            let id = part.trimmingCharacters(in: .whitespaces)
            if !id.isEmpty && !ids.contains(id) { ids.append(id) }
        }
        return ids
    }

    public static func raw(_ ids: [String]) -> String { ids.joined(separator: ",") }

    public static func contains(_ id: String, in raw: String) -> Bool { parse(raw).contains(id) }

    /// The stored value with `id` added or removed
    public static func setting(_ id: String, inTeam: Bool, in raw: String) -> String {
        var ids = parse(raw)
        if inTeam {
            if !ids.contains(id) { ids.append(id) }
        } else {
            ids = ids.filter { other in other != id }
        }
        return TeamRoster.raw(ids)
    }

    public static func ids(in defaults: UserDefaults = UserDefaults.standard) -> [String] {
        parse(defaults.string(forKey: TeamRoster.storageKey) ?? "")
    }

    public static func replace(_ ids: [String], in defaults: UserDefaults = UserDefaults.standard) {
        defaults.set(TeamRoster.raw(ids), forKey: TeamRoster.storageKey)
    }
}

/// Team matches and the team flags in the full backup (format 4). Both
/// platforms call this from their backup code: `attach` when a backup is
/// made, `restore` after the rest of the file was restored.
public enum TeamBackup {
    /// The backup with this phone's team matches and team players added
    public static func attach(_ backup: FullBackup, directory: URL) -> FullBackup {
        var result = backup
        var matches = TeamMatchFile.read(in: directory)
        // The live key of an evening is no use after the evening: not in the file
        for index in 0..<matches.count {
            matches[index].liveId = nil
            matches[index].liveKey = nil
            matches[index].liveOwnerKey = nil
        }
        // Always written, also empty: a restore that replaces everything must be
        // able to tell "this phone has none" from "an older file that does not say"
        result.teamMatches = matches
        result.teamPlayerIds = TeamRoster.ids()
        return result
    }

    /// Merging adds the matches that are not there yet (the newest edit of a
    /// match wins) and the team players; replacing swaps them for the file's,
    /// but only for what the file has, so an older file wipes nothing.
    /// Throws when the file cannot be written, so the restore does not report
    /// "done" for team matches that were not saved. Returns how many team
    /// matches were added (not the ones that were updated).
    @discardableResult
    public static func restore(_ backup: FullBackup, directory: URL, replacing: Bool) throws -> Int {
        var added = 0
        if let incoming = backup.teamMatches {
            var current: [TeamMatch] = replacing ? [] : try TeamMatchFile.load(in: directory)
            for match in incoming {
                var found = false
                for index in 0..<current.count where current[index].id == match.id {
                    found = true
                    if match.updatedAt > current[index].updatedAt { current[index] = match.normalized() }
                }
                if !found {
                    current.append(match.normalized())
                    added += 1
                }
            }
            try TeamMatchFile.write(current, in: directory)
        }
        if let ids = backup.teamPlayerIds {
            var merged: [String] = replacing ? [] : TeamRoster.ids()
            for id in ids where !merged.contains(id) { merged.append(id) }
            TeamRoster.replace(merged)
        }
        return added
    }
}

/// Loads the players of Mijn team (the SBN team page) into Spelers, once per
/// team link, and marks them "In mijn team". A name already in Spelers only
/// gets the mark; nothing else of that player changes.
public enum TeamRosterSync {
    /// The team link (source URL) the players were last loaded for
    public static let syncedKey = "teamRosterSyncedFor"

    public static func needsSync(_ snapshot: LeagueTeamSnapshot, in defaults: UserDefaults = UserDefaults.standard) -> Bool {
        !snapshot.players.isEmpty && defaults.string(forKey: syncedKey) != snapshot.source.absoluteString
    }

    /// Returns how many new players were made; 0 when it already ran for this link.
    /// A failing store leaves the link unmarked, so the next start tries again.
    @MainActor @discardableResult
    public static func run(_ snapshot: LeagueTeamSnapshot, store: any PlayerProfileStore,
                           in defaults: UserDefaults = UserDefaults.standard) async -> Int {
        guard needsSync(snapshot, in: defaults) else { return 0 }
        guard var known = try? await store.loadPlayers() else { return 0 }
        var ids = TeamRoster.ids(in: defaults)
        var added = 0
        do {
            for incoming in snapshot.players {
                let name = incoming.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if name.isEmpty { continue }
                var matchId: String? = nil
                for player in known where TeamMatch.sameTeam(player.name, name) { matchId = player.id }
                if matchId == nil {
                    let made = PlayerProfile(name: name)
                    try await store.savePlayer(made)
                    known.append(made)
                    matchId = made.id
                    added += 1
                }
                if let matchId, !ids.contains(matchId) { ids.append(matchId) }
            }
        } catch {
            TeamRoster.replace(ids, in: defaults)
            return added
        }
        TeamRoster.replace(ids, in: defaults)
        defaults.set(snapshot.source.absoluteString, forKey: syncedKey)
        return added
    }
}
