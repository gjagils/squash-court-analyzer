import Foundation

/// The name of a player on the live page, the lock screen and the alerts of a
/// team match: the first name, and when another known player has the same
/// first name the first letter of the surname, tussenvoegsels left out
/// ("Paul van Rijn" → "Paul R", "Niels de Groot" → "Niels G"; Gerd-Jan,
/// 21 October 2026). Known players: everyone in the team match and the
/// players of Mijn team, so "Niels G" also shows when Niels S is not playing.
/// Never more than the letters needed (two when the first letters are equal too).
public enum LiveNames {
    /// Dutch (and a few other) tussenvoegsels, compared in lower case
    static let infixes: [String] = ["van", "de", "der", "den", "het", "'t", "t", "te", "ten", "ter",
                                    "in", "op", "aan", "bij", "uit", "von", "la", "le", "du", "di", "da", "d'"]

    /// "Paul R" when `known` has another Paul, else "Paul"; "" for an empty name
    public static func label(_ fullName: String, among known: [String]) -> String {
        let first = LiveSnapshot.firstName(fullName, fallback: "")
        if first.isEmpty { return "" }
        let surname = surnameOf(fullName)
        if surname.isEmpty { return first }
        let me = normalized(fullName)
        var others: [String] = []
        for name in known {
            if normalized(name) == me || normalized(name).isEmpty { continue }
            if LiveSnapshot.firstName(name, fallback: "").lowercased() != first.lowercased() { continue }
            let theirs = surnameOf(name)
            if !others.contains(theirs) { others.append(theirs) }
        }
        if others.isEmpty { return first }
        var length = 1
        while length < 2 && others.contains(where: { other in initial(other, length) == initial(surname, length) }) {
            length += 1
        }
        return first + " " + initial(surname, length)
    }

    /// The names a team match knows: its own players and opponents in every
    /// partij, and the players of Mijn team
    public static func known(in match: TeamMatch, team: LeagueTeamSnapshot? = TeamMatchSupport.cachedTeam()) -> [String] {
        var names: [String] = []
        for partij in match.partijen {
            names.append(partij.ownPlayer)
            names.append(partij.opponentPlayer)
        }
        if let team {
            for player in team.players { names.append(player.name) }
        }
        return names
    }

    /// The surname without first name and tussenvoegsels: "Paul van Rijn" → "Rijn"
    static func surnameOf(_ fullName: String) -> String {
        let words = fullName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .components(separatedBy: " ").filter { word in !word.isEmpty }
        if words.count < 2 { return "" }
        var index = 1
        while index < words.count - 1 && infixes.contains(words[index].lowercased()) { index += 1 }
        var kept = ""
        for character in words[index] where isLetter(character) { kept += String(character) }
        return kept
    }

    /// The first `length` letters, the first in capitals: "Steenks", 1 → "S"; 2 → "St"
    static func initial(_ surname: String, _ length: Int) -> String {
        var result = ""
        for character in surname {
            if result.count >= length { break }
            result += result.isEmpty ? String(character).uppercased() : String(character).lowercased()
        }
        return result
    }

    /// Character.isLetter is not in Skip; Kotlin's Char.isLetter() is the same test
    static func isLetter(_ character: Character) -> Bool {
        #if SKIP
        return character.isLetter()
        #else
        return character.isLetter
        #endif
    }

    static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
    }
}
