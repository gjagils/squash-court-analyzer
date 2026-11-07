import Foundation

// MARK: - Competitie: all matches in one order

/// One line in Competitie: a team match on this phone, or a match of the
/// programme of Mijn team that has none yet
public struct CompetitionEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let date: Date
    public let match: TeamMatch?
    public let fixture: LeagueFixture?

    init(match: TeamMatch) {
        self.id = match.id.uuidString
        self.date = match.date
        self.match = match
        self.fixture = nil
    }

    init(fixture: LeagueFixture) {
        self.id = fixture.id
        self.date = fixture.date
        self.match = nil
        self.fixture = fixture
    }
}

/// The order of Competitie (Gerd-Jan, 7 November 2026): today and the coming
/// matches by date, a line, then the matches of the past from old to recent.
/// A match of today stays above the line for the whole day.
public struct CompetitionOverview: Equatable, Sendable {
    public let coming: [CompetitionEntry]
    public let past: [CompetitionEntry]

    public var isEmpty: Bool { coming.isEmpty && past.isEmpty }

    public static func make(matches: [TeamMatch], fixtures: [LeagueFixture], now: Date = Date()) -> CompetitionOverview {
        var entries: [CompetitionEntry] = []
        for match in matches { entries.append(CompetitionEntry(match: match)) }
        for fixture in fixtures where match(for: fixture, in: matches, among: fixtures) == nil { entries.append(CompetitionEntry(fixture: fixture)) }

        let calendar = Calendar.current
        var coming: [CompetitionEntry] = []
        var past: [CompetitionEntry] = []
        for entry in entries {
            if entry.date >= now || calendar.isDate(entry.date, inSameDayAs: now) {
                coming.append(entry)
            } else {
                past.append(entry)
            }
        }
        return CompetitionOverview(coming: coming.sorted(by: { a, b in a.date < b.date }),
                                   past: past.sorted(by: { a, b in a.date < b.date }))
    }

    init(coming: [CompetitionEntry], past: [CompetitionEntry]) {
        self.coming = coming
        self.past = past
    }

    /// By its SBN match; a copy joined before it took its fixture by day and teams
    static func hasMatch(_ fixture: LeagueFixture, in matches: [TeamMatch]) -> Bool {
        match(for: fixture, in: matches) != nil
    }

    /// The team match on this phone for a match of the programme (Mijn team
    /// shows it with its stand and LIVE), or nil: by its SBN match, else the
    /// same day and teams. A live team match without its SBN match (typed in on
    /// another day) belongs to the first coming match not played yet with the
    /// same home and away team (Gerd-Jan, 7 November 2026); `among` is the whole
    /// programme, so a later match with the same teams is not taken too.
    public static func match(for fixture: LeagueFixture, in matches: [TeamMatch],
                             among fixtures: [LeagueFixture] = []) -> TeamMatch? {
        let calendar = Calendar.current
        for match in matches where match.fixtureId == fixture.id { return match }
        for match in matches where match.fixtureId == nil && calendar.isDate(match.date, inSameDayAs: fixture.date)
            && TeamMatch.sameTeam(match.home, fixture.home) && TeamMatch.sameTeam(match.away, fixture.away) {
            return match
        }
        guard fixture.score == nil else { return nil }
        for other in fixtures where other.id != fixture.id && other.score == nil && other.date < fixture.date
            && TeamMatch.sameTeam(other.home, fixture.home) && TeamMatch.sameTeam(other.away, fixture.away) {
            return nil
        }
        for match in matches where match.fixtureId == nil && match.isLive
            && TeamMatch.sameTeam(match.home, fixture.home) && TeamMatch.sameTeam(match.away, fixture.away) {
            return match
        }
        return nil
    }
}
