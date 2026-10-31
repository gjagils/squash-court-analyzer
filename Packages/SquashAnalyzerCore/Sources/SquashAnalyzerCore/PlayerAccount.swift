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
        session = nil
        profile = nil
        profileChecked = false
        inbox = []
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
        profile = try await client().me(token: token)
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
                                                                                 sbnPath: path, consent: true))
        profileChecked = true
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

    public func loadInbox() async throws {
        let token = try await validToken()
        inbox = try await client().inbox(token: token)
    }

    /// Gebruiken, Niet gebruiken, or Blokkeren (not use, and refuse that phone from now on)
    public func answer(matchId: String, use: Bool, block: Bool = false) async throws {
        let token = try await validToken()
        _ = try await client().answer(token: token, matchId: matchId, use: use, block: block)
        inbox = inbox.filter { match in match.matchId != matchId }
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
