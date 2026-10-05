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
        let matches = TeamMatchFile.read(in: directory)
        result.teamMatches = matches.isEmpty ? nil : matches
        let ids = TeamRoster.ids()
        result.teamPlayerIds = ids.isEmpty ? nil : ids
        return result
    }

    /// Merging adds the matches that are not there yet (the newest edit of a
    /// match wins) and the team players; replacing swaps them for the file's,
    /// but only for what the file has, so an older file wipes nothing.
    public static func restore(_ backup: FullBackup, directory: URL, replacing: Bool) {
        if let incoming = backup.teamMatches {
            var current: [TeamMatch] = replacing ? [] : TeamMatchFile.read(in: directory)
            for match in incoming {
                var found = false
                for index in 0..<current.count where current[index].id == match.id {
                    found = true
                    if match.updatedAt > current[index].updatedAt { current[index] = match }
                }
                if !found { current.append(match) }
            }
            try? TeamMatchFile.write(current, in: directory)
        }
        if let ids = backup.teamPlayerIds {
            var merged: [String] = replacing ? [] : TeamRoster.ids()
            for id in ids where !merged.contains(id) { merged.append(id) }
            TeamRoster.replace(merged)
        }
    }
}
