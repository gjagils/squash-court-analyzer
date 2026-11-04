import Foundation

// 4.0, behind Features.shared.playerAccount: the matches in your account come
// to your phone (Gerd-Jan, 1 November 2026: "meteen samenvoegen"). A match you
// accepted, claimed or added from a link becomes an ordinary match in
// Afgeronde wedstrijden, saved through the history store, so its badges count
// for your own player in Spelers and its analysis opens like any other.
// Coaching notes never come along (they stay on the coach's phone). A match
// this phone recorded itself is left alone, an imported match is never sent on
// to the players again, and one you delete does not come back.

/// The ids of the matches that came from the account, and how far the sync got
public enum AccountImports {
    public static let idsKey = "accountImportedMatches"
    /// Kept as text: milliseconds do not fit Android's 32-bit Int
    public static let sinceKey = "accountImportedSinceMillis"

    public static func ids(in defaults: UserDefaults = UserDefaults.standard) -> [String] {
        TeamRoster.parse(defaults.string(forKey: AccountImports.idsKey) ?? "")
    }

    /// An imported match: queueing it for the players again would send their own match back
    public static func contains(_ id: UUID, in defaults: UserDefaults = UserDefaults.standard) -> Bool {
        ids(in: defaults).contains(id.uuidString.uppercased())
    }

    static func add(_ id: String, in defaults: UserDefaults) {
        var list = ids(in: defaults)
        let clean = id.uppercased()
        if list.contains(clean) { return }
        list.append(clean)
        defaults.set(TeamRoster.raw(list), forKey: AccountImports.idsKey)
    }

    /// Milliseconds since 1970 of the newest decision seen; 0 for everything
    public static func since(in defaults: UserDefaults = UserDefaults.standard) -> Int64 {
        Int64(defaults.string(forKey: AccountImports.sinceKey) ?? "") ?? Int64(0)
    }

    static func setSince(_ value: Int64, in defaults: UserDefaults) {
        defaults.set("\(value)", forKey: AccountImports.sinceKey)
    }

    /// Signing out or deleting the account: the next account starts from the beginning
    public static func reset(in defaults: UserDefaults = UserDefaults.standard) {
        defaults.removeObject(forKey: AccountImports.sinceKey)
    }
}

public extension AccountMatch {
    /// A match from the account as a coach match for Afgeronde wedstrijden.
    /// A referee's match comes along the same way (it has no slagen or vakken,
    /// like eenvoudig coachen). `ownPlayerId` goes on the side that is you.
    /// Nil without rallies (an inbox entry) or with an id that is not a UUID.
    static func match(from server: AccountServerMatch, ownPlayerId: String?) -> Match? {
        guard let rallies = server.rallies, let id = UUID(uuidString: server.matchId) else { return nil }
        let summary = server.summary
        let match = Match(id: id)
        match.player1Name = summary.p1
        match.player2Name = summary.p2
        match.bestOf = max(1, summary.gamesToWin * 2 - 1)
        if summary.gamesBefore.count == 2 {
            match.player1GamesBefore = summary.gamesBefore[0]
            match.player2GamesBefore = summary.gamesBefore[1]
        }
        if let ownPlayerId, let ownId = UUID(uuidString: ownPlayerId) {
            if summary.me == 2 { match.player2Id = ownId } else { match.player1Id = ownId }
        }
        var startMillis = server.playedAt
        if let started = summary.startedAt { startMillis = started }
        var clock = Date(timeIntervalSince1970: Double(startMillis) / 1000.0)
        var games: [Game] = []
        for stored in rallies {
            let game = Game()
            game.player1Name = summary.p1
            game.player2Name = summary.p2
            game.startedAt = clock
            var p1 = 0
            var p2 = 0
            var first = true
            var parsed: [BadgeRally] = []
            for text in stored.rallies {
                if let rally = AccountRally.rally(text) { parsed.append(rally) }
            }
            // Untimed rallies share what is left of the game's stored duration, so
            // the game lasts as long as it did (badges like Sneltrein look at that)
            var timed = 0.0
            var untimed = 0
            for rally in parsed {
                if let seconds = rally.duration, seconds > 0.0 { timed += seconds } else { untimed += 1 }
            }
            var untimedStep = 20.0
            let gameSeconds = stored.duration ?? 0.0
            if gameSeconds > 0.0 && untimed > 0 { untimedStep = max(0.0, gameSeconds - timed) / Double(untimed) }
            for rally in parsed {
                if rally.winner == Player.player1 { p1 += 1 } else { p2 += 1 }
                let duration = rally.duration ?? 0.0
                clock = clock.addingTimeInterval(duration > 0.0 ? duration : untimedStep)
                let server = rally.server ?? rally.winner
                if first {
                    game.startingServer = server
                    first = false
                }
                game.points.append(Point(scorer: rally.winner, pointType: rally.pointType ?? PointType.rally,
                                         zone: rally.zone, shotType: rally.shot, server: server,
                                         player1Score: p1, player2Score: p2, timestamp: clock,
                                         duration: duration, isVolley: rally.isVolley))
            }
            game.player1Score = p1
            game.player2Score = p2
            game.lastPointTime = clock
            games.append(game)
            // The break between games
            clock = clock.addingTimeInterval(90.0)
        }
        guard !games.isEmpty else { return nil }
        match.games = games
        match.currentGameIndex = games.count - 1
        match.status = MatchStatus.completed
        let played = Date(timeIntervalSince1970: Double(server.playedAt) / 1000.0)
        match.playedAt = played
        match.updatedAt = played
        return match
    }
}

/// Brings the account's matches to this phone. Each platform hands over its
/// stores at start (`configure`); `run` is called at start and after a match
/// is accepted, claimed or added from a link.
@MainActor
public final class AccountSync {
    public static let shared = AccountSync()

    private var history: (any MatchHistoryStore)? = nil
    private var players: (any PlayerProfileStore)? = nil
    private var running = false
    /// How many matches the last run brought in (for a line in Mijn account)
    public private(set) var lastImported = 0

    public init() {}

    public func configure(history: any MatchHistoryStore, players: any PlayerProfileStore) {
        self.history = history
        self.players = players
    }

    /// Fetches what was decided since the last run and saves the new matches.
    /// Returns how many came in; 0 without network, account or stores.
    @discardableResult
    public func run(account: PlayerAccount = PlayerAccount.shared,
                    in defaults: UserDefaults = UserDefaults.standard) async -> Int {
        guard Features.shared.playerAccount, !running, let history, let players, account.isSignedIn else { return 0 }
        running = true
        defer { running = false }
        if account.profile == nil { try? await account.loadProfile() }
        guard let profile = account.profile,
              let list = try? await account.acceptedMatches(since: AccountImports.since(in: defaults)) else { return 0 }
        let ownId = await AccountSync.ownPlayerId(profile, store: players, in: defaults)
        var newest = AccountImports.since(in: defaults)
        var imported = 0
        for item in list {
            if let decided = item.decidedAt, decided > newest { newest = decided }
            let id = item.matchId.uppercased()
            if AccountImports.ids(in: defaults).contains(id) { continue }
            // Recorded on this phone (an own match, or one you coached yourself): it is here already
            if await AccountSync.isHere(id, history: history) {
                AccountImports.add(id, in: defaults)
                continue
            }
            guard let match = AccountMatch.match(from: item, ownPlayerId: ownId) else { continue }
            // Marked before saving, so the save does not queue it for the players again
            AccountImports.add(id, in: defaults)
            do {
                try await history.saveCoachMatch(match)
                imported += 1
            } catch {
                continue
            }
        }
        AccountImports.setSince(newest, in: defaults)
        lastImported = imported
        return imported
    }

    /// The match is in this phone's history already (ids in either case: Room keeps them as written)
    static func isHere(_ id: String, history: any MatchHistoryStore) async -> Bool {
        for candidate in [id, id.lowercased()] {
            do {
                if try await history.coachMatch(id: candidate) != nil { return true }
                if try await history.refereeMatch(id: candidate) != nil { return true }
            } catch {
                continue
            }
        }
        return false
    }

    /// You in Spelers: the player with your account name, else the one linked to
    /// your SBN player, else a new player with that name (linked from now on).
    /// The name goes first (Gerd-Jan, 4 November 2026): a nickname on this phone
    /// may hold your SBN link, and it keeps that link so its matches still reach you.
    static func ownPlayerId(_ profile: AccountProfile, store: any PlayerProfileStore,
                            in defaults: UserDefaults) async -> String? {
        guard let known = try? await store.loadPlayers() else { return nil }
        let links = PlayerSBNLinks.all(in: defaults)
        for player in known where TeamMatch.sameTeam(player.name, profile.name) {
            if let path = profile.sbnPath, !links.values.contains(path), PlayerSBNLinks.path(for: player.id, in: defaults) == nil {
                PlayerSBNLinks.set(path, for: player.id, in: defaults)
            }
            return player.id
        }
        if let path = profile.sbnPath {
            for (id, linked) in links where linked == path {
                if known.contains(where: { player in player.id.lowercased() == id.lowercased() }) { return id }
            }
        }
        let made = PlayerProfile(name: profile.name)
        guard (try? await store.savePlayer(made)) != nil else { return nil }
        if let path = profile.sbnPath { PlayerSBNLinks.set(path, for: made.id, in: defaults) }
        return made.id
    }
}
