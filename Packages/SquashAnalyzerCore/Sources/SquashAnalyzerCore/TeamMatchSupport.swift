import Foundation

// MARK: - Een bijgehouden wedstrijd voor een partij (Competitie)
//
// The coupling between a tracked coach or referee match and a partij of a
// team match, and what that does with the stores and the live page. Pure
// logic (no screens), so it is tested in Core and shared by iOS and Android.

/// A coach or referee match played for a partij of a team match: the names
/// to start with and where the result goes when the match is over (and, when
/// the team match is live, where its state goes while it is played).
public struct TeamTarget: Equatable {
    public let teamMatchId: UUID
    public let slot: Int
    public let ownPlayer: String
    public let opponentPlayer: String
    /// Our player is Speler 1 of the tracked match
    public let ownIsPlayer1: Bool
    public let ownSide: TeamSide
    /// The live team match, when there is one
    public let liveId: String?
    public let liveKey: String?
    /// How the live page names the home and the away player: a first name, or
    /// empty for the default ("Squash Delft 8 E1")
    public let homeLabel: String
    public let awayLabel: String

    public init(teamMatchId: UUID, slot: Int, ownPlayer: String, opponentPlayer: String, ownIsPlayer1: Bool,
                ownSide: TeamSide = TeamSide.home, liveId: String? = nil, liveKey: String? = nil,
                homeLabel: String = "", awayLabel: String = "") {
        self.teamMatchId = teamMatchId
        self.slot = slot
        self.ownPlayer = ownPlayer
        self.opponentPlayer = opponentPlayer
        self.ownIsPlayer1 = ownIsPlayer1
        self.ownSide = ownSide
        self.liveId = liveId
        self.liveKey = liveKey
        self.homeLabel = homeLabel
        self.awayLabel = awayLabel
    }

    public var player1Name: String { ownIsPlayer1 ? ownPlayer : opponentPlayer }
    public var player2Name: String { ownIsPlayer1 ? opponentPlayer : ownPlayer }
    /// The home player of the team match is Speler 1 of the tracked match
    public var homeIsPlayer1: Bool { ownIsPlayer1 == (ownSide == TeamSide.home) }

    /// The target for `slot`: with nothing filled in the names are the
    /// defaults, and as a rule the home player starts as Speler 1 (as SBN prints it)
    public static func make(team: TeamMatch, slot: Int, ownIsPlayer1: Bool? = nil,
                            ownName: String? = nil, opponentName: String? = nil) -> TeamTarget {
        let partij = team.partij(slot)
        let own = ownName ?? team.ownDisplayName(partij)
        let opponent = opponentName ?? team.opponentDisplayName(partij)
        let ownFirst = ownIsPlayer1 ?? (team.ownSide == TeamSide.home)
        func label(_ name: String, _ standard: String) -> String {
            TeamMatch.sameTeam(name, standard) ? "" : LiveSnapshot.firstName(name, fallback: "")
        }
        let ownLabel = label(own, team.defaultOwnName(slot))
        let opponentLabel = label(opponent, team.defaultOpponentName(slot))
        return TeamTarget(teamMatchId: team.id, slot: slot, ownPlayer: own, opponentPlayer: opponent, ownIsPlayer1: ownFirst,
                          ownSide: team.ownSide, liveId: team.liveId, liveKey: team.liveKey,
                          homeLabel: team.ownSide == TeamSide.home ? ownLabel : opponentLabel,
                          awayLabel: team.ownSide == TeamSide.home ? opponentLabel : ownLabel)
    }

    /// Which player of the finished match is ours: by name, else as started
    public func ownIsPlayer1(in match1: String, _ match2: String) -> Bool {
        let own = ownPlayer.trimmingCharacters(in: .whitespaces).lowercased()
        if !own.isEmpty && match1.trimmingCharacters(in: .whitespaces).lowercased() == own { return true }
        if !own.isEmpty && match2.trimmingCharacters(in: .whitespaces).lowercased() == own { return false }
        return ownIsPlayer1
    }

    /// Starts forwarding a tracked match to the live page of this team match
    @MainActor public func bind(matchId: UUID) {
        guard let liveId, let liveKey else { return }
        TeamLive.shared.bind(matchId: matchId, teamId: liveId, writeKey: liveKey, slot: slot,
                             homeIsPlayer1: homeIsPlayer1, homeLabel: homeLabel, awayLabel: awayLabel)
    }
}

public enum TeamMatchSupport {
    /// Puts the team match on the live page ("Deel met mijn team"): makes the
    /// page, keeps its keys in the team match and sends what is filled in.
    /// Throws when the page cannot be made; the team match is then unchanged.
    @MainActor public static func goLive(_ match: TeamMatch, store: any TeamMatchStore,
                                         live: TeamLive = TeamLive.shared) async throws -> TeamMatch {
        let created = try await live.create(match)
        var changed = match
        changed.liveId = created.id
        changed.liveKey = created.writeKey
        changed.liveOwnerKey = created.ownerKey
        try await store.save(changed)
        await live.pushAll(changed)
        return changed
    }

    /// A match started for a partij is remembered in the team match, so that
    /// leaving and resuming it later picks the coupling up again
    @MainActor public static func track(_ target: TeamTarget, matchId: UUID, store: any TeamMatchStore) async {
        guard let all = try? await store.loadAll() else { return }
        for var team in all where team.id == target.teamMatchId {
            team.startTracking(slot: target.slot, matchId: matchId.uuidString, ownIsPlayer1: target.ownIsPlayer1,
                               ownPlayer: target.ownPlayer, opponentPlayer: target.opponentPlayer)
            try? await store.save(team)
        }
    }

    /// A tracked match was discarded or saved as incomplete: the partij is free again
    @MainActor public static func untrack(matchId: UUID, store: any TeamMatchStore) async {
        guard let all = try? await store.loadAll() else { return }
        for var team in all where team.partijTracking(matchId: matchId.uuidString) != nil {
            team.stopTracking(matchId: matchId.uuidString)
            try? await store.save(team)
        }
        TeamLive.shared.unbind(matchId: matchId)
    }

    /// The coupling of a resumed match, from the team match it was started for
    @MainActor public static func target(forMatchId id: UUID, store: any TeamMatchStore) async -> TeamTarget? {
        guard let all = try? await store.loadAll() else { return nil }
        for team in all {
            if let partij = team.partijTracking(matchId: id.uuidString) {
                return TeamTarget.make(team: team, slot: partij.slot, ownIsPlayer1: partij.trackingOwnIsPlayer1,
                                       ownName: team.ownDisplayName(partij), opponentName: team.opponentDisplayName(partij))
            }
        }
        return nil
    }

    /// The finished coach match goes into the partij it was started for
    @MainActor public static func link(coach match: Match, target: TeamTarget, store: any TeamMatchStore) async {
        guard let all = try? await store.loadAll() else { return }
        for var team in all where team.id == target.teamMatchId {
            var partij = team.partij(target.slot)
            partij.link(coach: match, ownIsPlayer1: target.ownIsPlayer1(in: match.player1Name, match.player2Name))
            team.update(partij)
            try? await store.save(team)
            _ = await TeamLive.shared.push(team.partij(target.slot), in: team)
        }
        TeamLive.shared.unbind(matchId: match.id)
    }

    /// The match-day question was answered: the finished match goes into that
    /// partij, through the same route as a match started for it (stored again
    /// from what is stored now, so what teammates put on the live page in the
    /// meantime is not overwritten, and the live page gets the result)
    @MainActor public static func linkOnMatchDay(coach match: Match, team: TeamMatch, slot: Int, ownIsPlayer1: Bool,
                                                 store: any TeamMatchStore) async {
        await ensureStored(team, store: store)
        let target = TeamTarget.make(team: team, slot: slot, ownIsPlayer1: ownIsPlayer1,
                                     ownName: ownIsPlayer1 ? match.player1Name : match.player2Name,
                                     opponentName: ownIsPlayer1 ? match.player2Name : match.player1Name)
        await link(coach: match, target: target, store: store)
    }

    @MainActor public static func linkOnMatchDay(referee match: RefereeMatch, team: TeamMatch, slot: Int, ownIsPlayer1: Bool,
                                                 store: any TeamMatchStore) async {
        await ensureStored(team, store: store)
        let target = TeamTarget.make(team: team, slot: slot, ownIsPlayer1: ownIsPlayer1,
                                     ownName: ownIsPlayer1 ? match.player1Name : match.player2Name,
                                     opponentName: ownIsPlayer1 ? match.player2Name : match.player1Name)
        await link(referee: match, target: target, store: store)
    }

    /// A team match from the fixtures of Mijn team is not saved until a partij is linked
    @MainActor private static func ensureStored(_ team: TeamMatch, store: any TeamMatchStore) async {
        if let all = try? await store.loadAll() {
            for stored in all where stored.id == team.id { return }
        }
        try? await store.save(team)
    }

    /// The finished referee match goes into the partij it was started for
    @MainActor public static func link(referee match: RefereeMatch, target: TeamTarget, store: any TeamMatchStore) async {
        guard let all = try? await store.loadAll() else { return }
        for var team in all where team.id == target.teamMatchId {
            var partij = team.partij(target.slot)
            partij.link(referee: match, ownIsPlayer1: target.ownIsPlayer1(in: match.player1Name, match.player2Name))
            team.update(partij)
            try? await store.save(team)
            _ = await TeamLive.shared.push(team.partij(target.slot), in: team)
        }
        TeamLive.shared.unbind(matchId: match.id)
    }

    /// The names to offer as our player: the players marked "In mijn team"
    /// first, then the players of Mijn team, without doubles
    public static func rosterNames(players: [PlayerProfile], team: LeagueTeamSnapshot?, rosterRaw: String) -> [String] {
        let ids = TeamRoster.parse(rosterRaw)
        var names: [String] = []
        for player in players where ids.contains(player.id) {
            if !names.contains(player.name) { names.append(player.name) }
        }
        if let team {
            for player in team.players where !names.contains(player.name) { names.append(player.name) }
        }
        return names
    }

    /// Mijn team as last fetched (Instellingen holds the link), for the
    /// fixtures and the roster; nil without a link
    public static func cachedTeam() -> LeagueTeamSnapshot? {
        let saved = UserDefaults.standard.string(forKey: LeagueTeamStorage.linkKey) ?? ""
        guard !saved.isEmpty, let link = try? LeagueTeamLink(saved) else { return nil }
        return LeagueTeamStorage.cachedSnapshot(for: link)
    }

    /// Team matches a new coach or referee match can belong to: the saved ones
    /// that are not decided yet (nearest to today first), then the coming
    /// matches of Mijn team that have no team match yet (not saved until used)
    @MainActor public static func candidates(store: any TeamMatchStore, now: Date = Date()) async -> [TeamMatch] {
        var result: [TeamMatch] = []
        var taken: [String] = []
        if let all = try? await store.loadAll() {
            var open: [TeamMatch] = []
            for match in all {
                if let id = match.fixtureId { taken.append(id) }
                if !match.isComplete { open.append(match) }
            }
            result = open.sorted(by: { a, b in abs(a.date.timeIntervalSince(now)) < abs(b.date.timeIntervalSince(now)) })
        }
        if let team = cachedTeam() {
            let from = now.addingTimeInterval(-24.0 * 3600.0)
            let until = now.addingTimeInterval(14.0 * 24.0 * 3600.0)
            for fixture in team.fixtures where fixture.date >= from && fixture.date <= until && !taken.contains(fixture.id) {
                result.append(TeamMatch.from(fixture: fixture, ownTeam: team.name))
            }
        }
        return Array(result.prefix(6))
    }

    /// The team match of today, to ask about after a coach or referee match:
    /// one already started on this phone, else a match of Mijn team played
    /// today (not saved until a partij is linked). Nil on an ordinary day.
    @MainActor public static func candidate(store: any TeamMatchStore, now: Date = Date()) async -> TeamMatch? {
        let calendar = Calendar.current
        if let all = try? await store.loadAll() {
            // A team match that is decided is not asked about again (a practice game after the team match)
            for match in all where calendar.isDate(match.date, inSameDayAs: now) && !match.isComplete { return match }
        }
        guard let team = cachedTeam() else { return nil }
        for fixture in team.fixtures where calendar.isDate(fixture.date, inSameDayAs: now) {
            return TeamMatch.from(fixture: fixture, ownTeam: team.name)
        }
        return nil
    }
}
