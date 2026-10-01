import Foundation

/// Two sample players, Bombardino and Whiskey, delivered with the app so a new
/// user can try a match with "Kies speler" straight away. They come in as a
/// team zip (`Resources/voorbeeldspelers.zip`, same format as a team import)
/// on a fresh install only: once, and only when there are no players yet.
/// Deleted sample players never come back.
public enum SamplePlayers {
    static let seededKey = "samplePlayersSeeded"

    /// The team zip with both players and their photos
    public static func zipData() -> Data? {
        guard let url = Bundle.module.url(forResource: "voorbeeldspelers", withExtension: "zip") else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Whether the sample players still have to be offered (never done before)
    public static var isPending: Bool {
        !UserDefaults.standard.bool(forKey: seededKey)
    }

    /// Done, whether they were added or skipped because there were players already
    public static func markDone() {
        UserDefaults.standard.set(true, forKey: seededKey)
    }
}
