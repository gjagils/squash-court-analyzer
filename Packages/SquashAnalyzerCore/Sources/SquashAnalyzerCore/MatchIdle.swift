import Foundation

// An unfinished coach or referee match that nobody touched for an hour is no
// longer "open" (Gerd-Jan, 21 November 2026): opening Coach or Scheidsrechter
// then goes straight to a new match instead of asking "Wedstrijd hervatten?",
// and the old one is kept as incomplete in Afgeronde wedstrijden (where
// "Uitslag aanvullen" still finishes it). The session notes when it last
// saved a match; a match without such a note (from an older build) is asked
// about as before.

public enum MatchIdle {
    /// How long a match may be left alone and still be asked about
    public static let interval: TimeInterval = 3600.0
    public static let coach = "coach"
    public static let referee = "referee"

    static func key(_ kind: String) -> String { "matchLastTouched." + kind }

    /// The session saved this match now
    public static func touch(_ id: UUID, kind: String, now: Date = Date(), defaults: UserDefaults = UserDefaults.standard) {
        defaults.set("\(id.uuidString)|\(Int64(now.timeIntervalSince1970))", forKey: key(kind))
    }

    /// Whether this unfinished match was last saved more than `interval` ago.
    /// False when there is no note for it: then nothing is known.
    public static func isIdle(_ id: UUID, kind: String, now: Date = Date(), defaults: UserDefaults = UserDefaults.standard) -> Bool {
        guard let note = defaults.string(forKey: key(kind)) else { return false }
        let parts = note.components(separatedBy: "|")
        guard parts.count == 2, parts[0] == id.uuidString, let seconds = Int64(parts[1]) else { return false }
        return now.timeIntervalSince1970 - Double(seconds) > interval
    }
}
