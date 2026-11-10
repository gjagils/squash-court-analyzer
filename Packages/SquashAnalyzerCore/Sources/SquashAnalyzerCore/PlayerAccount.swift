import Foundation
import Observation

// 4.0: the player account for the screens (Instellingen → Mijn account and the
// inbox), behind `Features.shared.playerAccount`. Ties Firebase sign-in
// (`FirebaseAuthREST`), the account Worker (`AccountClient`) and the outgoing
// queue (`AccountOutbox`) together. The app configures it at start when the
// switch is on; with the switch off nothing here is ever called.

/// Where the lasting secrets go: the Firebase refresh token and the device key
/// (iOS: Keychain, Android: an Android-Keystore-encrypted value)
public protocol AccountSecretStore: AnyObject {
    /// One JSON text (`AccountSecrets`); nil when nothing is stored
    var accountSecrets: String? { get set }
}

/// For tests and previews
public final class MemoryAccountSecrets: AccountSecretStore {
    public var accountSecrets: String? = nil

    public init() {}
}

/// What `AccountSecretStore` keeps
public struct AccountSecrets: Codable, Equatable, Sendable {
    public var session: AuthSession?
    /// The device key stays after signing out: it is this phone's, not the player's
    public var device: AccountDevice?

    public init(session: AuthSession? = nil, device: AccountDevice? = nil) {
        self.session = session
        self.device = device
    }
}

/// The system photo picker for the avatar, on each platform: a centre-cropped
/// square JPEG of at most 512 px; nil when the user cancelled
@MainActor
public protocol AccountAvatarSource: AnyObject {
    func pickAvatar() async throws -> Data?
}

@MainActor
@Observable
public final class PlayerAccount {
    public static let shared = PlayerAccount()

    public private(set) var endpoints: AccountEndpoints? = nil
    private var transport: (any LiveTransport)? = nil
    private var secrets: (any AccountSecretStore)? = nil
    public private(set) var outbox: AccountOutbox = AccountOutbox.shared

    /// Signed in with Firebase (the account itself may not exist yet)
    public private(set) var session: AuthSession? = nil
    /// The account on the Worker; nil when not signed in or not made yet
    public private(set) var profile: AccountProfile? = nil
    /// `profile` was asked for since signing in, so nil means "no account yet"
    public private(set) var profileChecked = false
    public private(set) var inbox: [AccountServerMatch] = []
    /// Matches of the own team that wait for a name ("Ben jij dit?")
    public private(set) var teamInbox: [AccountServerMatch] = []
    /// A "Stuur naar speler" link that was opened (`AccountClaimLink`): the app shows it until handled
    public var pendingClaim: String? = nil
    /// Your own avatar as shown in Mijn account (loaded with `loadOwnAvatar`)
    public private(set) var ownAvatar: Data? = nil
    /// Picks a photo for the avatar: set by each platform at start; nil hides "Foto kiezen"
    public var avatarSource: (any AccountAvatarSource)? = nil
    private var device: AccountDevice? = nil
    private var sending = false

    public init() {}

    public var isConfigured: Bool { endpoints != nil && transport != nil }
    public var isSignedIn: Bool { session != nil }

    public func configure(endpoints: AccountEndpoints, transport: any LiveTransport, secrets: any AccountSecretStore,
                          outbox: AccountOutbox = AccountOutbox.shared) {
        self.endpoints = endpoints
        self.transport = transport
        self.secrets = secrets
        self.outbox = outbox
        let stored = PlayerAccount.read(secrets.accountSecrets)
        session = stored.session
        device = stored.device
        profile = nil
        profileChecked = false
        inbox = []
        teamInbox = []
    }

    // MARK: Signing in

    public func register(email: String, password: String) async throws {
        let auth = try firebase()
        let fresh = try await auth.signUp(email: PlayerAccount.cleanEmail(email), password: password)
        signedIn(fresh)
        // The verification mail is a courtesy: the account works without it
        try? await auth.sendEmailVerification(idToken: fresh.idToken)
        try await loadProfile()
    }

    public func signIn(email: String, password: String) async throws {
        let fresh = try await firebase().signIn(email: PlayerAccount.cleanEmail(email), password: password)
        signedIn(fresh)
        try await loadProfile()
    }

    /// With a token from Sign in with Apple or Google (`providerId` "apple.com" / "google.com")
    public func signIn(providerId: String, idToken: String, nonce: String?) async throws {
        let fresh = try await firebase().signIn(providerId: providerId, idToken: idToken, nonce: nonce)
        signedIn(fresh)
        try await loadProfile()
    }

    public func sendPasswordReset(email: String) async throws {
        try await firebase().sendPasswordReset(email: PlayerAccount.cleanEmail(email))
    }

    /// Forgets the session on this phone; the account and its data stay
    public func signOut() {
        AccountImports.reset()
        session = nil
        profile = nil
        profileChecked = false
        inbox = []
        teamInbox = []
        ownAvatar = nil
        storeSecrets()
    }

    /// A valid ID token, refreshed when it is about to expire. A refresh token
    /// that no longer works signs out.
    public func validToken(now: Date = Date()) async throws -> String {
        guard let current = session else { throw AccountError.signInAgain }
        if current.isFresh(at: now) { return current.idToken }
        do {
            let fresh = try await firebase().refresh(current, now: now)
            session = fresh
            storeSecrets()
            return fresh.idToken
        } catch let error as AccountError {
            if error == AccountError.signInAgain { signOut() }
            throw error
        }
    }

    // MARK: The account

    /// Asks the Worker for the account (nil profile: none made yet)
    public func loadProfile() async throws {
        let token = try await validToken()
        do {
            profile = try await client().me(token: token)
        } catch let error as AccountError {
            // The Worker refuses this session (another Firebase project, a
            // deleted user): sign out here, so the screen offers signing in again
            if error == AccountError.signInAgain { signOut() }
            throw error
        }
        profileChecked = true
    }

    /// "Dit ben ik", the birth year and the consent. Under 16 the Worker refuses
    /// as well (`AccountError.tooYoung`); the screen asks before that.
    public func createAccount(name: String, birthYear: Int, sbnPath: String?, consent: Bool) async throws {
        let trimmed = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmed.isEmpty { throw AccountError.missingName }
        if !consent { throw AccountError.missingConsent }
        let year = Calendar(identifier: Calendar.Identifier.gregorian).component(Calendar.Component.year, from: Date())
        if birthYear > AccountCreation.latestBirthYear(in: year) { throw AccountError.tooYoung }
        let token = try await validToken()
        var path: String? = nil
        if let sbnPath, !sbnPath.isEmpty { path = sbnPath }
        profile = try await client().createAccount(token: token, AccountCreation(name: trimmed, birthYear: birthYear,
                                                                                 sbnPath: path, teamKey: AccountSending.ownTeamKey(),
                                                                                 consent: true))
        profileChecked = true
    }

    /// A typo in the name, or "Dit ben ik" (the SBN player, once) chosen later.
    /// The team follows Mijn team.
    public func updateAccount(name: String? = nil, sbnPath: String? = nil) async throws {
        var cleanName: String? = nil
        if let name {
            let trimmed = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if trimmed.isEmpty { throw AccountError.missingName }
            cleanName = trimmed
        }
        var path: String? = nil
        if let sbnPath, !sbnPath.isEmpty { path = sbnPath }
        let token = try await validToken()
        profile = try await client().updateAccount(token: token, AccountUpdate(name: cleanName, sbnPath: path,
                                                                                teamKey: AccountSending.ownTeamKey()))
    }

    /// The account's team follows Mijn team on this phone (set or changed since)
    func followOwnTeam() async {
        guard let current = profile, let team = AccountSending.ownTeamKey(), current.teamKey != team,
              let token = try? await validToken() else { return }
        if let updated = try? await client().updateAccount(token: token, AccountUpdate(teamKey: team)) { profile = updated }
    }

    /// Deletes the account and everything on the server, then the Firebase user.
    /// For an Apple account pass the authorization code of a fresh Sign in with
    /// Apple: Apple requires the token to be revoked (since 2022).
    public func deleteAccount(appleAuthorizationCode: String? = nil) async throws {
        let token = try await validToken()
        let auth = try firebase()
        if let appleAuthorizationCode {
            try await auth.revokeAppleToken(idToken: token, authorizationCode: appleAuthorizationCode)
        }
        try await client().deleteAccount(token: token)
        // The data is gone; a Firebase user left behind (no network just now) holds nothing
        try? await auth.deleteUser(idToken: token)
        outbox.removeOwn()
        signOut()
    }

    // MARK: The inbox

    /// The inbox and the team's matches that wait for a name
    public func loadInbox() async throws {
        let token = try await validToken()
        await followOwnTeam()
        inbox = try await client().inbox(token: token)
        let hidden = PlayerAccount.hiddenTeamMatches()
        teamInbox = try await client().teamMatches(token: token).filter { match in !hidden.contains(match.matchId) }
    }

    /// "Dat ben ik": the team match counts at once
    public func claimTeamMatch(_ match: AccountServerMatch) async throws {
        let token = try await validToken()
        _ = try await client().claimTeamMatch(token: token, matchId: match.matchId, name: match.name ?? "")
        teamInbox = teamInbox.filter { other in other.matchId != match.matchId }
        // Other matches of that coach for that name may have moved to the inbox
        inbox = try await client().inbox(token: token)
    }

    /// "Niet ik": hidden on this phone only, the match stays for the teammate it is for
    public func hideTeamMatch(_ match: AccountServerMatch, in defaults: UserDefaults = UserDefaults.standard) {
        teamInbox = teamInbox.filter { other in other.matchId != match.matchId }
        var hidden = PlayerAccount.hiddenTeamMatches(in: defaults)
        if !hidden.contains(match.matchId) { hidden.append(match.matchId) }
        // The server wipes waiting matches after 90 days: the newest few hundred are plenty
        defaults.set(TeamRoster.raw(Array(hidden.suffix(300))), forKey: PlayerAccount.hiddenTeamMatchesKey)
    }

    /// "Niet ik" survives a restart: the ids, comma separated like `TeamRoster`
    public static let hiddenTeamMatchesKey = "accountHiddenTeamMatches"

    static func hiddenTeamMatches(in defaults: UserDefaults = UserDefaults.standard) -> [String] {
        TeamRoster.parse(defaults.string(forKey: PlayerAccount.hiddenTeamMatchesKey) ?? "")
    }

    /// A match from a shared link: it counts at once
    public func claimLink(_ claimToken: String) async throws -> AccountServerMatch {
        let token = try await validToken()
        return try await client().claimLink(token: token, claimToken: claimToken)
    }

    /// Gebruiken, Niet gebruiken, or Blokkeren (not use, and refuse that phone from now on)
    public func answer(matchId: String, use: Bool, block: Bool = false) async throws {
        let token = try await validToken()
        _ = try await client().answer(token: token, matchId: matchId, use: use, block: block)
        inbox = inbox.filter { match in match.matchId != matchId }
    }

    // MARK: Finding team matches (4.0, docs/voorstel-teamwedstrijd-vinden-4.0.md)

    /// What `TeamFinding` needs, when the switch is on, someone is signed in
    /// and the account has a team (Mijn team); nil otherwise
    public func teamFindingContext() async -> TeamFindingContext? {
        guard Features.shared.playerAccount, isSignedIn else { return nil }
        if profile == nil { try? await loadProfile() }
        await followOwnTeam()
        guard let teamKey = profile?.teamKey, !teamKey.isEmpty,
              let token = try? await validToken(), let accountClient = try? client() else { return nil }
        return TeamFindingContext(client: accountClient, token: token, teamKey: teamKey)
    }

    // MARK: Avatar (Gerd-Jan, 10 November 2026)

    /// Your avatar from the server, when the profile says there is one
    public func loadOwnAvatar() async throws {
        guard profile?.avatarVersion != nil else {
            ownAvatar = nil
            return
        }
        let token = try await validToken()
        ownAvatar = try await client().ownAvatar(token: token)
    }

    /// Puts a new avatar up (a small square JPEG); whoever picks you as a player may see it
    public func setAvatar(_ jpeg: Data) async throws {
        let token = try await validToken()
        _ = try await client().setAvatar(token: token, jpeg: jpeg)
        ownAvatar = jpeg
        profile = try await client().me(token: token)
    }

    public func deleteAvatar() async throws {
        let token = try await validToken()
        try await client().deleteAvatar(token: token)
        ownAvatar = nil
        profile = try await client().me(token: token)
    }

    /// The avatar versions of these SBN players (with this phone's device key; no account needed)
    public func avatarVersions(sbnPaths: [String]) async throws -> [String: Int64] {
        let key = try await deviceKey()
        return try await client().avatarVersions(device: key, sbnPaths: sbnPaths)
    }

    public func avatar(sbnPath: String) async throws -> Data? {
        let key = try await deviceKey()
        return try await client().avatar(device: key, sbnPath: sbnPath)
    }

    /// "Foto melden"
    public func reportAvatar(sbnPath: String) async throws {
        let key = try await deviceKey()
        try await client().reportAvatar(device: key, sbnPath: sbnPath)
    }

    // MARK: Sending

    /// This phone's device key, made once
    public func deviceKey() async throws -> AccountDevice {
        if let device { return device }
        let made = try await client().createDevice()
        device = made
        storeSecrets()
        return made
    }

    /// Sends what waits in the outbox. Stops at the first sign of no network;
    /// the next call (app start, back online) carries on.
    public func sendOutbox(now: Date = Date()) async {
        if sending || !isConfigured { return }
        sending = true
        defer { sending = false }
        outbox.remove(outbox.stale(now: now))
        guard let api = try? client() else { return }

        // Own matches in batches, when signed in with an account
        var own: [AccountOutboxEntry] = outbox.entries.filter { entry in entry.isOwn }
        if !own.isEmpty && profile != nil {
            while !own.isEmpty {
                let batch = Array(own.prefix(50))
                own = Array(own.dropFirst(50))
                let keys = batch.map { entry in entry.key }
                do {
                    let token = try await validToken(now: now)
                    try await api.addOwnMatches(token: token, batch.map { entry in entry.match })
                    outbox.remove(keys)
                } catch let error as AccountError {
                    if error == AccountError.noConnection { return }
                    if PlayerAccount.isPermanent(error) {
                        outbox.remove(keys)
                    } else {
                        outbox.countAttempt(keys)
                        return
                    }
                } catch {
                    return
                }
            }
        }

        // Matches for others, one by one, with the device key
        for entry in outbox.entries.filter({ entry in !entry.isOwn }) {
            guard let to = entry.recipient else { continue }
            do {
                let key = try await deviceKey()
                try await api.submit(device: key, AccountSubmission(match: entry.match, to: to, senderName: entry.senderName))
                outbox.remove([entry.key])
            } catch let error as AccountError {
                if error == AccountError.noConnection { return }
                if error == AccountError.signInAgain {
                    // The Worker no longer knows this device key: make a new one next time
                    device = nil
                    storeSecrets()
                    outbox.countAttempt([entry.key])
                    return
                }
                if PlayerAccount.isPermanent(error) {
                    outbox.remove([entry.key])
                } else {
                    outbox.countAttempt([entry.key])
                    return
                }
            } catch {
                return
            }
        }
    }

    /// Accepted matches decided after `since` (milliseconds), with their rallies (`AccountSync`)
    public func acceptedMatches(since: Int64) async throws -> [AccountServerMatch] {
        let token = try await validToken()
        return try await client().matches(token: token, since: since)
    }

    /// What teammates' claims taught this phone, into `PlayerSBNLinks`. Only
    /// with a device key (a phone that sent something); returns how many players got linked.
    @discardableResult
    public func learnLinks(players: [PlayerProfile]) async -> Int {
        guard isConfigured, let device, let api = try? client(),
              let learned = try? await api.learnedLinks(device: device) else { return 0 }
        return PlayerSBNLinks.learn(learned, players: players, teamKey: AccountSending.ownTeamKey())
    }

    /// Sends one finished match to whoever opens the link; the token for the link comes back
    public func shareLink(_ match: AccountMatchUpload, senderName: String) async throws -> String {
        let key = try await deviceKey()
        let result = try await client().submit(device: key, AccountSubmission(match: match, to: AccountRecipient(link: true),
                                                                               senderName: senderName))
        guard let token = result?.claimToken else { throw AccountError.invalidResponse }
        return token
    }

    /// The Worker refused the match itself (400): sending it again will not help
    static func isPermanent(_ error: AccountError) -> Bool {
        switch error {
        case .server(let status): return status == 400 || status == 413
        default: return false
        }
    }

    // MARK: Plumbing

    private func firebase() throws -> FirebaseAuthREST {
        guard let endpoints, let transport else { throw AccountError.notConfigured }
        return FirebaseAuthREST(endpoints: endpoints, transport: transport)
    }

    private func client() throws -> AccountClient {
        guard let endpoints, let transport else { throw AccountError.notConfigured }
        return AccountClient(baseURL: endpoints.accountURL, transport: transport)
    }

    private func signedIn(_ fresh: AuthSession) {
        session = fresh
        profile = nil
        profileChecked = false
        inbox = []
        storeSecrets()
    }

    private func storeSecrets() {
        guard let secrets else { return }
        let value = AccountSecrets(session: session, device: device)
        guard let data = try? JSONEncoder().encode(value) else { return }
        secrets.accountSecrets = String(data: data, encoding: String.Encoding.utf8)
    }

    static func read(_ text: String?) -> AccountSecrets {
        guard let text, let data = text.data(using: String.Encoding.utf8),
              let value = try? JSONDecoder().decode(AccountSecrets.self, from: data) else { return AccountSecrets() }
        return value
    }

    /// The players of Mijn team (cached from sbn.toernooi.nl), for "Dit ben ik";
    /// their id is the SBN player path. Empty without a team link.
    public static func mijnTeamPlayers(in defaults: UserDefaults = UserDefaults.standard) -> [LeaguePlayer] {
        let link = defaults.string(forKey: LeagueTeamStorage.linkKey) ?? ""
        guard !link.isEmpty, let parsed = try? LeagueTeamLink(link),
              let snapshot = LeagueTeamStorage.cachedSnapshot(for: parsed, in: defaults) else { return [] }
        return snapshot.players
    }

    static func cleanEmail(_ email: String) -> String {
        email.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
    }
}
