import Foundation

// A reminder after two weeks (Gerd-Jan, 11 November 2026): whoever has neither
// a team (Mijn team) nor an account 14 days after first opening 4.0 sees the
// "Speel je competitie bij SBN?" card and the "Maak je account" block once
// more, even when they tapped them away. Tapped away again, they stay away.
// In the app only: no notification, no permission needed.
public enum SetupReminder {
    /// Milliseconds of the first start of 4.0, as text (Android's Int is 32 bits)
    public static let firstSeenKey = "setupReminderFirstSeenMillis"
    /// The reminder came once
    public static let shownKey = "setupReminderShown"
    /// The keys of the two blocks that can be tapped away
    public static let teamPromptKey = "teamPromptDismissed"
    public static let accountNudgeKey = "accountNudgeHidden"
    public static let days: Int64 = 14

    /// Whether the two blocks should come back now
    public static func isDue(firstSeen: Int64, now: Int64, hasTeam: Bool, hasAccount: Bool, shown: Bool) -> Bool {
        if shown || hasTeam || hasAccount || firstSeen <= 0 { return false }
        return now - firstSeen >= days * 86_400_000
    }

    /// Called when the home screen appears: remembers the first start, and
    /// once the reminder is due brings both blocks back. Returns true when it did.
    @discardableResult
    public static func check(hasTeam: Bool, hasAccount: Bool, now: Date = Date(),
                             in defaults: UserDefaults = UserDefaults.standard) -> Bool {
        let nowMillis = Int64(now.timeIntervalSince1970 * 1000.0)
        let stored = Int64(defaults.string(forKey: SetupReminder.firstSeenKey) ?? "") ?? Int64(0)
        if stored <= 0 {
            defaults.set("\(nowMillis)", forKey: SetupReminder.firstSeenKey)
            return false
        }
        guard isDue(firstSeen: stored, now: nowMillis, hasTeam: hasTeam, hasAccount: hasAccount,
                    shown: defaults.bool(forKey: SetupReminder.shownKey)) else { return false }
        defaults.set(true, forKey: SetupReminder.shownKey)
        defaults.set(false, forKey: SetupReminder.teamPromptKey)
        defaults.set(false, forKey: SetupReminder.accountNudgeKey)
        return true
    }
}
