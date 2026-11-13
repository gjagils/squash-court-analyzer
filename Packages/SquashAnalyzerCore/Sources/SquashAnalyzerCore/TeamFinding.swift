import Foundation

// 4.0, behind Features.shared.playerAccount (docs/voorstel-teamwedstrijd-vinden-4.0.md,
// Gerd-Jan, 6 November 2026): a team match from the programme of Mijn team is
// visible to teammates with an account, and to the opponent, without an
// invitation. It is a live team match on the live Worker that stays off the
// club screen (`clubScreen: false`) until Live delen; the account Worker keeps
// a pointer to it per team and SBN match (`team_lives`). Teammates get the
// invitation key, the opponent a key for the partijen it referees.

/// Where the account side of finding comes from: the account Worker, a fresh
/// token and the team of the account. `PlayerAccount.teamFindingContext()`
/// makes one when the switch is on and the account has a team.
public struct TeamFindingContext: Sendable {
    public let client: AccountClient
    public let token: String
    /// "<league UUID>/<team number>" (`LeagueTeamLink.accountKey`)
    public let teamKey: String

    public init(client: AccountClient, token: String, teamKey: String) {
        self.client = client
        self.token = token
        self.teamKey = teamKey
    }
}

public enum TeamFindingError: Error, Equatable {
    /// The live team match is gone (or its key no longer works)
    case gone
    /// This phone has the match already, on another live team match
    case sharedElsewhere
    /// The opponent's entry has no referee key (another league)
    case noKey
}

/// What making a team match visible did
public enum TeamFindingOutcome: Equatable, Sendable {
    /// Our live team match, registered for the team
    case started
    /// A teammate had it already: this phone joined theirs (the starter's name)
    case joined(String)
}

/// The team match after making it visible, and how (no tuple: Skip)
public struct TeamFindingResult: Sendable {
    public let match: TeamMatch
    public let outcome: TeamFindingOutcome
}

@MainActor
public enum TeamFinding {
    /// Standard SBN refereeing: the home team referees match 1 and 3 of the
    /// evening (E4 and E1), the away team match 2 and 4 (E2 and E3). The
    /// opponent of the team that keeps the live team match referees these.
    public static func opponentRefereeSlots(keepingSide: TeamSide) -> [Int] {
        keepingSide == TeamSide.home ? [2, 3] : [1, 4]
    }

    /// The SBN match link with the league in capitals, as the account Worker
    /// keeps it ("/league/<UUID>/team-match/<n>"); nil for anything else
    public static func normalizedFixture(_ fixture: String?) -> String? {
        guard let fixture, TeamLiveListing.isFixture(fixture) else { return nil }
        let parts = fixture.components(separatedBy: "/")
        guard parts.count == 5, parts[1] == "league", parts[3] == "team-match", parts[2].count == 36,
              !parts[4].isEmpty else { return nil }
        return "/league/" + parts[2].uppercased() + "/team-match/" + parts[4]
    }

    /// The league of a team key or fixture, in capitals
    static func league(of text: String) -> String {
        for part in text.components(separatedBy: "/") where part.count == 36 { return part.uppercased() }
        return ""
    }

    /// Whether this team match can be visible for the team: from the programme
    /// of the account's team (same league)
    public static func canShare(_ match: TeamMatch, context: TeamFindingContext) -> Bool {
        guard let fixture = normalizedFixture(match.fixtureId) else { return false }
        return league(of: fixture) == league(of: context.teamKey) && !league(of: fixture).isEmpty
    }

    static func sameFixture(_ a: String?, _ b: String?) -> Bool {
        guard let left = normalizedFixture(a), let right = normalizedFixture(b) else { return false }
        return left == right
    }

    // MARK: Making it visible

    /// A new team match from the programme becomes visible for the team: a
    /// teammate's live team match for it is joined, otherwise one is made
    /// (off the club screen, with a key for the opponent) and registered.
    /// Throws when nothing could be made; the match is then unchanged.
    public static func makeVisible(_ match: TeamMatch, context: TeamFindingContext, store: any TeamMatchStore,
                                   live: TeamLive? = nil) async throws -> TeamFindingResult {
        let live = live ?? TeamLive.shared
        guard canShare(match, context: context), let fixture = normalizedFixture(match.fixtureId) else {
            throw TeamFindingError.noKey
        }
        // Someone of the team may have made it already
        var replaces: String? = nil
        if let lives = try? await context.client.teamLives(token: context.token, fixtures: []) {
            for listing in lives where listing.own && listing.fixture == fixture {
                if let joined = try? await joinOwn(listing, into: match, store: store, live: live) {
                    return TeamFindingResult(match: joined, outcome: TeamFindingOutcome.joined(listing.starterName))
                }
                // Its live team match is gone: ours replaces it
                replaces = listing.liveId
            }
        }
        let slots = opponentRefereeSlots(keepingSide: match.ownSide)
        let created = try await live.create(match, teamOnly: true, refereeSlots: slots)
        var changed = match
        changed.liveId = created.id
        changed.liveKey = created.writeKey
        changed.liveOwnerKey = created.ownerKey
        changed.liveTeamOnly = true
        changed.liveRefereeKey = created.refereeKey
        changed.refereeSlots = nil
        try await store.save(changed)
        await live.pushAll(changed)
        let registration = TeamLiveRegistration(fixture: fixture, date: Int64(match.date.timeIntervalSince1970 * 1000.0),
                                                teamName: match.ownName, liveId: created.id, writeKey: created.writeKey,
                                                refereeKey: created.refereeKey, replaces: replaces)
        guard let registered = try? await context.client.registerTeamLive(token: context.token, registration) else {
            // Not registered (no connection to the account Worker): the live team
            // match works, teammates join it with the invitation
            return TeamFindingResult(match: changed, outcome: TeamFindingOutcome.started)
        }
        if registered.wasThereFirst {
            // A teammate made it at the same moment: ours goes, theirs is joined
            var plain = changed
            plain.clearLiveState()
            if let joined = try? await joinOwn(registered.listing, into: plain, store: store, live: live) {
                await live.stop(changed)
                return TeamFindingResult(match: joined, outcome: TeamFindingOutcome.joined(registered.listing.starterName))
            }
        }
        return TeamFindingResult(match: changed, outcome: TeamFindingOutcome.started)
    }

    /// Our match takes the teammate's live team match; what was filled in here stays and goes up
    static func joinOwn(_ listing: TeamLiveListing, into match: TeamMatch, store: any TeamMatchStore,
                        live: TeamLive) async throws -> TeamMatch {
        guard let key = listing.writeKey else { throw TeamFindingError.noKey }
        let state: TeamLiveState
        do {
            _ = try await live.verify(id: listing.liveId, key: key)
            state = try await live.fetch(id: listing.liveId)
        } catch {
            throw TeamFindingError.gone
        }
        let joined = match.linked(to: state, invite: TeamInvite(id: listing.liveId, key: key))
        try await store.save(joined)
        await live.pushAll(joined)
        return joined
    }

    // MARK: Finding

    /// The live team matches to offer: the own team's, and the opponent's for
    /// the matches of today and tomorrow in the programme (only with a referee
    /// key). Those this phone already follows are left out.
    public static func offers(context: TeamFindingContext, fixtures: [LeagueFixture], matches: [TeamMatch],
                              now: Date = Date()) async -> [TeamLiveListing] {
        var asked: [String] = []
        for fixture in fixtures where abs(fixture.date.timeIntervalSince(now)) < 36.0 * 3600.0 {
            if let normalized = normalizedFixture(fixture.id), !asked.contains(normalized) { asked.append(normalized) }
        }
        guard let lives = try? await context.client.teamLives(token: context.token, fixtures: asked) else { return [] }
        var result: [TeamLiveListing] = []
        for listing in lives {
            if !listing.own && listing.refereeKey == nil { continue }
            var followed = false
            for match in matches where match.liveId == listing.liveId { followed = true }
            if !followed { result.append(listing) }
        }
        return result
    }

    /// Joins an offer: the own team's with the invitation key, the opponent's
    /// with the referee key (only its refereed partijen go up from here). An
    /// own match for the same SBN match without a live team match takes it;
    /// `fixtures` (the programme) gives it the fixture id this phone uses.
    public static func join(_ listing: TeamLiveListing, ownTeamName: String, fixtures: [LeagueFixture],
                            store: any TeamMatchStore, live: TeamLive? = nil) async throws -> TeamMatch {
        let live = live ?? TeamLive.shared
        guard let key = listing.own ? listing.writeKey : listing.refereeKey else { throw TeamFindingError.noKey }
        let state: TeamLiveState
        var slots: [Int]? = nil
        do {
            let access = try await live.verifyAccess(id: listing.liveId, key: key)
            if !listing.own { slots = access.slots }
            state = try await live.fetch(id: listing.liveId)
        } catch {
            throw TeamFindingError.gone
        }
        let invite = TeamInvite(id: listing.liveId, key: key)
        let keepingSide: TeamSide = TeamMatch.sameTeam(state.team.away, listing.teamName) ? TeamSide.away : TeamSide.home
        var ownSide = listing.own ? keepingSide : keepingSide.other
        if TeamMatch.sameTeam(state.team.home, ownTeamName) { ownSide = TeamSide.home }
        if TeamMatch.sameTeam(state.team.away, ownTeamName) { ownSide = TeamSide.away }
        var fixtureId = listing.fixture
        for fixture in fixtures where sameFixture(fixture.id, listing.fixture) { fixtureId = fixture.id }

        let all = try await store.loadAll()
        // Joined before: that copy, with what the page has now
        for var existing in all where existing.liveId == listing.liveId {
            _ = existing.mergeLive(state)
            try await store.save(existing)
            return existing
        }
        for existing in all where sameFixture(existing.fixtureId, listing.fixture) {
            if existing.isLive { throw TeamFindingError.sharedElsewhere }
            var linked = existing.linked(to: state, invite: invite)
            linked.refereeSlots = slots
            try await store.save(linked)
            await live.pushAll(linked)
            return linked
        }
        var match = TeamMatch.joining(state, invite: invite, ownSide: ownSide)
        match.fixtureId = fixtureId
        match.refereeSlots = slots
        try await store.save(match)
        return match
    }

    // MARK: After a match (Gerd-Jan, 13 November 2026)

    /// The team match to ask about after a coach or referee match ("hoort
    /// deze wedstrijd erbij?"): the one of today on this phone
    /// (`TeamMatchSupport.candidate`), and with an account a teammate's live
    /// team match of today that this phone has not joined yet. That one comes
    /// back as it would be after joining, not saved:
    /// `TeamMatchSupport.linkOnMatchDay` stores it once a partij is chosen, so
    /// "Nee, gewone wedstrijd" joins nothing. Without an account, a
    /// connection or a find it is the local answer.
    public static func matchDayCandidate(store: any TeamMatchStore, context: TeamFindingContext? = nil,
                                         live: TeamLive? = nil, now: Date = Date()) async -> TeamMatch? {
        let local = await TeamMatchSupport.candidate(store: store, now: now)
        if let local, local.isLive { return local }
        let account: TeamFindingContext?
        if let context {
            account = context
        } else {
            account = await PlayerAccount.shared.teamFindingContext()
        }
        guard let account, let lives = try? await account.client.teamLives(token: account.token, fixtures: []) else { return local }
        let live = live ?? TeamLive.shared
        let all = (try? await store.loadAll()) ?? []
        let team = TeamMatchSupport.cachedTeam()
        let calendar = Calendar.current
        for listing in lives where listing.own {
            guard let key = listing.writeKey,
                  calendar.isDate(Date(timeIntervalSince1970: Double(listing.matchAt) / 1000.0), inSameDayAs: now) else { continue }
            if let local {
                // The match of today on this phone is another one: that one is asked about
                if !sameFixture(local.fixtureId, listing.fixture) { continue }
            } else {
                // Joined before or decided here: not asked about again
                var known = false
                for match in all where match.liveId == listing.liveId || sameFixture(match.fixtureId, listing.fixture) { known = true }
                if known { continue }
            }
            let state: TeamLiveState
            do {
                _ = try await live.verify(id: listing.liveId, key: key)
                state = try await live.fetch(id: listing.liveId)
            } catch {
                continue
            }
            let invite = TeamInvite(id: listing.liveId, key: key)
            var found: TeamMatch
            if let local {
                found = local.linked(to: state, invite: invite)
            } else {
                var ownSide: TeamSide = TeamMatch.sameTeam(state.team.away, listing.teamName) ? TeamSide.away : TeamSide.home
                if let team {
                    if TeamMatch.sameTeam(state.team.home, team.name) { ownSide = TeamSide.home }
                    if TeamMatch.sameTeam(state.team.away, team.name) { ownSide = TeamSide.away }
                }
                found = TeamMatch.joining(state, invite: invite, ownSide: ownSide)
                found.fixtureId = listing.fixture
                if let team {
                    for fixture in team.fixtures where sameFixture(fixture.id, listing.fixture) { found.fixtureId = fixture.id }
                }
            }
            if found.isComplete { continue }
            return found
        }
        return local
    }

    // MARK: Ending

    /// The team match leaves the list of the team (stopped or deleted here):
    /// only the own registration goes; best effort
    public static func forget(_ match: TeamMatch, context: TeamFindingContext) async {
        guard match.isLiveOwner, let fixture = normalizedFixture(match.fixtureId) else { return }
        try? await context.client.removeTeamLive(token: context.token, fixture: fixture)
    }

    /// The partijen the opponent referees now (the owner's referee key), or nil when unknown
    public static func currentRefereeSlots(_ match: TeamMatch, live: TeamLive? = nil) async -> [Int]? {
        let live = live ?? TeamLive.shared
        guard let id = match.liveId, let key = match.liveRefereeKey,
              let access = try? await live.verifyAccess(id: id, key: key) else { return nil }
        return access.slots
    }
}
