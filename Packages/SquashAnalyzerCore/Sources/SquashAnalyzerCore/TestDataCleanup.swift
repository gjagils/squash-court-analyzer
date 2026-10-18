import Foundation

/// What the one-time "Testgegevens opruimen" question offers to remove, per group
public enum TestDataGroup: String, CaseIterable, Sendable {
    /// Matches with the sample players of the test period (Bombardino, Whiskey)
    case samplePlayers
    /// Unfinished matches: incomplete ("Opslaan als incompleet") or paused ("Bewaar en ga later verder")
    case unfinished
    /// Team matches (Competitie)
    case competition

    public var title: String {
        switch self {
        case .samplePlayers: return "Wedstrijden met Bombardino of Whiskey"
        case .unfinished: return "Onvolledige en gepauzeerde wedstrijden"
        case .competition: return "Competitiewedstrijden"
        }
    }
}

/// How many items each group would remove
public struct TestDataCounts: Equatable, Sendable {
    public var samplePlayers: Int
    public var unfinished: Int
    public var competition: Int

    public init(samplePlayers: Int = 0, unfinished: Int = 0, competition: Int = 0) {
        self.samplePlayers = samplePlayers
        self.unfinished = unfinished
        self.competition = competition
    }

    public func count(_ group: TestDataGroup) -> Int {
        switch group {
        case .samplePlayers: return samplePlayers
        case .unfinished: return unfinished
        case .competition: return competition
        }
    }

    public var isEmpty: Bool { samplePlayers + unfinished + competition == 0 }

    /// The groups with something in them, in a fixed order
    public var groups: [TestDataGroup] { TestDataGroup.allCases.filter { group in count(group) > 0 } }
}

/// A coach or referee match as the cleanup sees it
public struct TestDataMatch: Equatable, Sendable {
    public let startedAt: Date
    public let player1Name: String
    public let player2Name: String
    public let isUnfinished: Bool

    public init(startedAt: Date, player1Name: String, player2Name: String, isUnfinished: Bool) {
        self.startedAt = startedAt
        self.player1Name = player1Name
        self.player2Name = player2Name
        self.isUnfinished = isUnfinished
    }
}

/// Reads and removes the test data; iOS over SwiftData, Android over Room.
/// Both use `TestDataCleanup.groups(of:)` so they pick the same matches.
@MainActor
public protocol TestDataCleanupStore: AnyObject {
    /// What each group would remove: matches and team matches from before `before`
    func counts(before: Date) async throws -> TestDataCounts
    /// A full backup, written before anything is removed
    func backUp() async throws
    /// Removes the coach and referee matches (their badges marked deleted, as a
    /// deletion from the history does) and team matches of the chosen groups
    func remove(_ groups: [TestDataGroup], before: Date) async throws
}

/// The one-time question at the first start after the badge reset
/// (`BadgeSeason`): remove the data of the test period? Only matches and team
/// matches from before the start, only when there is something, once per install.
public enum TestDataCleanup {
    public static let storageKey = "testDataCleanupDone"

    /// The sample players of the test period, recognised by name (the sample
    /// zip has no fixed ids). Bob and Wim, their successors, are ordinary names
    /// and so never count.
    public static let sampleNames = ["bombardino", "whiskey"]

    /// Whether to look for test data: the badge reset has started and the
    /// question was not answered yet
    public static func shouldOffer(done: Bool, start: Date? = BadgeSeason.start, now: Date = Date()) -> Bool {
        !done && BadgeSeason.activeStart(start: start, now: now) != nil
    }

    public static func isSamplePlayer(_ name: String) -> Bool {
        sampleNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    /// The groups a match from before `before` falls in (none when it is newer).
    /// A match can be in two groups; it goes when either is chosen.
    public static func groups(of match: TestDataMatch, before: Date) -> [TestDataGroup] {
        guard match.startedAt < before else { return [] }
        var result: [TestDataGroup] = []
        if isSamplePlayer(match.player1Name) || isSamplePlayer(match.player2Name) { result.append(TestDataGroup.samplePlayers) }
        if match.isUnfinished { result.append(TestDataGroup.unfinished) }
        return result
    }

    /// Whether a match goes when `chosen` groups are removed
    public static func removes(_ match: TestDataMatch, chosen: [TestDataGroup], before: Date) -> Bool {
        TestDataCleanup.groups(of: match, before: before).contains { group in chosen.contains(group) }
    }

    /// Adds up what `matches` and the team match dates give per group
    public static func counts(matches: [TestDataMatch], teamMatchDates: [Date], before: Date) -> TestDataCounts {
        var counts = TestDataCounts()
        for match in matches {
            let found = TestDataCleanup.groups(of: match, before: before)
            if found.contains(TestDataGroup.samplePlayers) { counts.samplePlayers += 1 }
            if found.contains(TestDataGroup.unfinished) { counts.unfinished += 1 }
        }
        for date in teamMatchDates where date < before {
            counts.competition += 1
        }
        return counts
    }
}
