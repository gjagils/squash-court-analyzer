import Foundation

/// The example players of earlier versions (Bombardino and Whiskey until 3.0,
/// then Bob and Wim). New installs no longer get them; an existing install is
/// asked once whether they may go. They are known by name only, so a player
/// marked "In mijn team" is a real one and is never offered.
public enum SamplePlayerCleanup {
    public static let doneKey = "samplePlayersQuestionDone"
    static let names = ["bob", "wim", "bombardino", "whiskey"]

    /// The players to ask about; `team` are the ids marked "In mijn team"
    public static func found(in players: [PlayerProfile], team: [String]) -> [PlayerProfile] {
        var result: [PlayerProfile] = []
        for player in players where names.contains(player.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
            var inTeam = false
            for id in team where id.lowercased() == player.id.lowercased() { inTeam = true }
            if !inTeam { result.append(player) }
        }
        return result
    }
}
