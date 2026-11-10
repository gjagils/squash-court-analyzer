import Foundation

// MARK: - Seizoensoverzicht per teamlid (4.0, T2)

/// One teammate's season (decision Gerd-Jan, 10 November 2026): the record
/// SBN shows on the team page, next to what the team matches in the app say
/// (partijen won and lost, games won and lost).
public struct TeamSeasonRow: Identifiable, Equatable, Sendable {
    public let name: String
    /// SBN's "3-1" (won-lost) parsed; nil when the team page shows none or something else
    public let sbnWon: Int?
    public let sbnLost: Int?
    /// From the team matches on this phone
    public let won: Int
    public let lost: Int
    public let gamesWon: Int
    public let gamesLost: Int
    /// On the SBN team page (an invaller from the app only is not)
    public let onTeamPage: Bool

    public var id: String { TeamBadges.key(name) }
    public var played: Int { won + lost }
    public var hasSbn: Bool { sbnWon != nil && sbnLost != nil }

    /// "SBN 3-1" or empty
    public var sbnText: String {
        guard let won = sbnWon, let lost = sbnLost else { return "" }
        return "SBN \(won)-\(lost)"
    }

    /// "In de app: 2 partijen, 2-0 · games 6-1"; nil when the app has none
    public var appText: String? {
        guard played > 0 else { return nil }
        let partijen = played == 1 ? L10n.text("1 partij") : L10n.text("%@ partijen", String(played))
        return L10n.text("In de app: %@, %@ · games %@", partijen, "\(won)-\(lost)", "\(gamesWon)-\(gamesLost)")
    }
}

public enum TeamSeason {
    /// "3-1" → (3, 1); anything else nil
    public static func parseRecord(_ record: String) -> (Int, Int)? {
        let parts = record.trimmingCharacters(in: .whitespaces).components(separatedBy: "-")
        guard parts.count == 2, let won = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let lost = Int(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
        return (won, lost)
    }

    /// The team matches of this team and this season: our side is the team
    /// (`TeamMatch.sameTeam`) and the match is not before the first match of
    /// the programme (a day's margin); without a programme every match of the team
    public static func seasonMatches(_ matches: [TeamMatch], team: LeagueTeamSnapshot) -> [TeamMatch] {
        var first: Date? = nil
        for fixture in team.fixtures {
            if let current = first, current <= fixture.date { continue }
            first = fixture.date
        }
        return TeamBadges.distinct(matches).filter { match in
            guard TeamMatch.sameTeam(match.ownName, team.name) else { return false }
            guard let first else { return true }
            return match.date >= first.addingTimeInterval(-86_400.0)
        }
    }

    /// A row per player of the SBN team page, in its order, then anyone who
    /// played a partij in the app but is not on the page (an invaller). A
    /// partij counts once decided; its games as the team score counts them.
    public static func rows(team: LeagueTeamSnapshot, matches: [TeamMatch]) -> [TeamSeasonRow] {
        var won: [String: Int] = [:]
        var lost: [String: Int] = [:]
        var gamesWon: [String: Int] = [:]
        var gamesLost: [String: Int] = [:]
        var names: [String: String] = [:]
        var order: [String] = []
        for match in seasonMatches(matches, team: team) {
            for partij in match.partijen {
                guard let ownWon = partij.ownWon else { continue }
                let key = TeamBadges.key(partij.ownPlayer)
                guard !key.isEmpty, key != TeamBadges.key(match.defaultOwnName(partij.slot)) else { continue }
                if names[key] == nil {
                    names[key] = partij.ownPlayer.trimmingCharacters(in: .whitespaces)
                    order.append(key)
                }
                if ownWon { won[key] = (won[key] ?? 0) + 1 } else { lost[key] = (lost[key] ?? 0) + 1 }
                gamesWon[key] = (gamesWon[key] ?? 0) + partij.ownGames
                gamesLost[key] = (gamesLost[key] ?? 0) + partij.theirGames
            }
        }
        var result: [TeamSeasonRow] = []
        var seen: Set<String> = []
        for player in team.players {
            let key = TeamBadges.key(player.name)
            if key.isEmpty || seen.contains(key) { continue }
            seen.insert(key)
            let record = parseRecord(player.record)
            result.append(TeamSeasonRow(name: player.name, sbnWon: record?.0, sbnLost: record?.1,
                                        won: won[key] ?? 0, lost: lost[key] ?? 0,
                                        gamesWon: gamesWon[key] ?? 0, gamesLost: gamesLost[key] ?? 0, onTeamPage: true))
        }
        for key in order where !seen.contains(key) {
            result.append(TeamSeasonRow(name: names[key] ?? key, sbnWon: nil, sbnLost: nil,
                                        won: won[key] ?? 0, lost: lost[key] ?? 0,
                                        gamesWon: gamesWon[key] ?? 0, gamesLost: gamesLost[key] ?? 0, onTeamPage: false))
        }
        return result
    }
}
