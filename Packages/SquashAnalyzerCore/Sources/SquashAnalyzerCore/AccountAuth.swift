import Foundation

// 4.0, the player account (docs/voorstel-spelersaccount-4.0.md), behind
// `Features.shared.playerAccount`. Signing in goes to Firebase Authentication
// through its REST API: plain HTTP from shared code, so there is no Firebase SDK
// on iOS and no skip-firebase on Android. Firebase keeps the passwords and sends
// the verification and reset mails; the account Worker (server/account-worker)
// checks the short-lived ID token on every request. Requests go through a
// `LiveTransport` (iOS: URLSession, Android: HttpURLConnection).

/// Where the account lives: the account Worker and Firebase Authentication
public struct AccountEndpoints: Equatable, Sendable {
    /// The account Worker, without a trailing slash
    public var accountURL: String
    /// Firebase's identitytoolkit API (`…/v1`)
    public var identityURL: String
    /// Firebase's securetoken API (`…/v1`), for refreshing the ID token
    public var tokenURL: String
    /// The Firebase Web API key (a public project identifier, not a secret)
    public var apiKey: String

    public init(accountURL: String, identityURL: String, tokenURL: String, apiKey: String) {
        self.accountURL = accountURL
        self.identityURL = identityURL
        self.tokenURL = tokenURL
        self.apiKey = apiKey
    }

    /// The Worker's address once it is deployed (server/account-worker/README.md)
    public static let productionAccountURL = "https://account.squashanalyzer.com"

    public static func production(apiKey: String) -> AccountEndpoints {
        AccountEndpoints(accountURL: AccountEndpoints.productionAccountURL,
                         identityURL: "https://identitytoolkit.googleapis.com/v1",
                         tokenURL: "https://securetoken.googleapis.com/v1",
                         apiKey: apiKey)
    }

    /// A local test setup on the Mac: `wrangler dev` on 8787 and the stand-in for
    /// Firebase from server/account-worker/dev on 9099 (the Firebase emulator's
    /// port and paths). `host` is "localhost" from the iOS simulator and
    /// "10.0.2.2" from the Android emulator.
    public static func local(host: String) -> AccountEndpoints {
        AccountEndpoints(accountURL: "http://\(host):8787",
                         identityURL: "http://\(host):9099/identitytoolkit.googleapis.com/v1",
                         tokenURL: "http://\(host):9099/securetoken.googleapis.com/v1",
                         apiKey: "local-dev")
    }

    /// From the build settings: "local" (or "local:<host>") for the test setup on
    /// the Mac, anything else the deployed Worker. `defaultHost` is the Mac as the
    /// simulator or emulator sees it.
    public static func from(server: String?, apiKey: String?, defaultHost: String) -> AccountEndpoints {
        let value = (server ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
        if value == "local" { return AccountEndpoints.local(host: defaultHost) }
        if value.hasPrefix("local:") {
            let host = value.replacingOccurrences(of: "local:", with: "")
            return AccountEndpoints.local(host: host.isEmpty ? defaultHost : host)
        }
        return AccountEndpoints.production(apiKey: apiKey ?? "")
    }
}

/// A signed-in Firebase user. The refresh token is the lasting secret (kept in
/// the Keychain or the Android Keystore, `AccountSecretStore`); the ID token lives an hour.
public struct AuthSession: Codable, Equatable, Sendable {
    public var uid: String
    public var email: String
    public var idToken: String
    public var refreshToken: String
    /// When the ID token expires, in milliseconds since 1970
    public var expiresAt: Int64
    /// "password", "apple.com" or "google.com"
    public var provider: String

    public init(uid: String, email: String, idToken: String, refreshToken: String, expiresAt: Int64, provider: String) {
        self.uid = uid
        self.email = email
        self.idToken = idToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.provider = provider
    }

    /// The ID token still has five minutes to go
    public func isFresh(at now: Date) -> Bool {
        expiresAt - Int64(5 * 60 * 1000) > AuthSession.millis(now)
    }

    static func millis(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000.0) }

    static func expiry(_ expiresIn: String?, from now: Date) -> Int64 {
        let seconds = Int64(expiresIn ?? "") ?? Int64(3600)
        return millis(now) + seconds * Int64(1000)
    }
}

/// What went wrong, in words for the screen
public enum AccountError: Error, Equatable {
    case noConnection
    case notConfigured
    case emailExists
    case wrongCredentials
    case weakPassword
    case invalidEmail
    case tooManyAttempts
    case userDisabled
    /// The refresh token no longer works (password changed, account deleted)
    case signInAgain
    case tooYoung
    case sbnPathTaken
    case missingConsent
    case missingName
    case notFound
    case tooManyRequests
    case invalidResponse
    case server(status: Int)

    public var message: String {
        switch self {
        case .noConnection: return L10n.text("Geen verbinding. Probeer het straks opnieuw.")
        case .notConfigured: return L10n.text("Inloggen is in deze build niet ingesteld.")
        case .emailExists: return L10n.text("Er is al een account met dit e-mailadres. Log in of kies Wachtwoord vergeten.")
        case .wrongCredentials: return L10n.text("Het e-mailadres of wachtwoord klopt niet.")
        case .weakPassword: return L10n.text("Kies een wachtwoord van minstens 6 tekens.")
        case .invalidEmail: return L10n.text("Dit e-mailadres klopt niet.")
        case .tooManyAttempts: return L10n.text("Te veel pogingen. Probeer het over een paar minuten opnieuw.")
        case .userDisabled: return L10n.text("Dit account is uitgeschakeld.")
        case .signInAgain: return L10n.text("Log opnieuw in.")
        case .tooYoung: return L10n.text("Een account kan vanaf 16 jaar. Je kunt de app gewoon zonder account gebruiken.")
        case .sbnPathTaken: return L10n.text("Deze SBN-speler hoort al bij een ander account.")
        case .missingConsent: return L10n.text("Zonder toestemming kan er geen account komen.")
        case .missingName: return L10n.text("Vul je naam in.")
        case .notFound: return L10n.text("Niet gevonden.")
        case .tooManyRequests: return L10n.text("Even te veel tegelijk. Probeer het later opnieuw.")
        case .invalidResponse: return L10n.text("Ongeldig antwoord van server")
        case .server(let status): return L10n.text("Serverfout (code: %@)", "\(status)")
        }
    }

    /// Firebase's error text ("EMAIL_EXISTS", "WEAK_PASSWORD : Password should be …")
    static func firebase(_ text: String, status: Int) -> AccountError {
        var code = ""
        for character in text {
            if character == " " || character == ":" { break }
            code += String(character)
        }
        switch code {
        case "EMAIL_EXISTS": return AccountError.emailExists
        case "EMAIL_NOT_FOUND", "INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS": return AccountError.wrongCredentials
        case "WEAK_PASSWORD": return AccountError.weakPassword
        case "INVALID_EMAIL", "MISSING_EMAIL": return AccountError.invalidEmail
        case "MISSING_PASSWORD": return AccountError.weakPassword
        case "TOO_MANY_ATTEMPTS_TRY_LATER": return AccountError.tooManyAttempts
        case "USER_DISABLED": return AccountError.userDisabled
        case "TOKEN_EXPIRED", "INVALID_REFRESH_TOKEN", "USER_NOT_FOUND", "INVALID_ID_TOKEN", "CREDENTIAL_TOO_OLD_LOGIN_AGAIN":
            return AccountError.signInAgain
        default: return AccountError.server(status: status)
        }
    }
}

// MARK: - Firebase Authentication (REST)

struct FirebasePasswordRequest: Codable {
    let email: String
    let password: String
    let returnSecureToken: Bool
}

struct FirebaseOobRequest: Codable {
    let requestType: String
    let email: String?
    let idToken: String?
}

struct FirebaseIdTokenRequest: Codable {
    let idToken: String
}

struct FirebaseIdpRequest: Codable {
    let postBody: String
    let requestUri: String
    let returnSecureToken: Bool
    let returnIdpCredential: Bool
}

struct FirebaseRevokeRequest: Codable {
    let idToken: String
    let providerId: String
    let tokenType: String
    let token: String
}

struct FirebaseRefreshRequest: Codable {
    let grantType: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
    }
}

/// The answer to signUp, signInWithPassword and signInWithIdp
struct FirebaseSignInResponse: Codable {
    let localId: String
    let email: String?
    let idToken: String
    let refreshToken: String
    let expiresIn: String?
}

struct FirebaseRefreshResponse: Codable {
    let idToken: String
    let refreshToken: String
    let expiresIn: String?
    let userId: String

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case userId = "user_id"
    }
}

struct FirebaseErrorBody: Codable {
    struct Detail: Codable {
        let message: String
    }
    let error: Detail
}

/// Firebase Authentication over REST: e-mail and password, a new password, the
/// verification mail, refreshing the ID token, deleting the user, and signing in
/// with an Apple or Google token
public struct FirebaseAuthREST: Sendable {
    public let endpoints: AccountEndpoints
    public let transport: any LiveTransport

    public init(endpoints: AccountEndpoints, transport: any LiveTransport) {
        self.endpoints = endpoints
        self.transport = transport
    }

    public func signUp(email: String, password: String, now: Date = Date()) async throws -> AuthSession {
        let body = FirebasePasswordRequest(email: email, password: password, returnSecureToken: true)
        return try await signIn("accounts:signUp", body: try JSONEncoder().encode(body), email: email, provider: "password", now: now)
    }

    public func signIn(email: String, password: String, now: Date = Date()) async throws -> AuthSession {
        let body = FirebasePasswordRequest(email: email, password: password, returnSecureToken: true)
        return try await signIn("accounts:signInWithPassword", body: try JSONEncoder().encode(body), email: email, provider: "password", now: now)
    }

    /// Signs in with a token from Sign in with Apple (`providerId` "apple.com",
    /// with the raw nonce the request was made with) or Google ("google.com")
    public func signIn(providerId: String, idToken: String, nonce: String?, now: Date = Date()) async throws -> AuthSession {
        var postBody = "id_token=\(idToken)&providerId=\(providerId)"
        if let nonce { postBody += "&nonce=\(nonce)" }
        let body = FirebaseIdpRequest(postBody: postBody, requestUri: "http://localhost", returnSecureToken: true, returnIdpCredential: true)
        return try await signIn("accounts:signInWithIdp", body: try JSONEncoder().encode(body), email: "", provider: providerId, now: now)
    }

    /// Firebase mails a link to choose a new password. Also succeeds for an
    /// address without an account when the project protects against e-mail enumeration.
    public func sendPasswordReset(email: String) async throws {
        let body = FirebaseOobRequest(requestType: "PASSWORD_RESET", email: email, idToken: nil)
        _ = try await post(identity("accounts:sendOobCode"), body: try JSONEncoder().encode(body))
    }

    /// Firebase mails a link to confirm the address
    public func sendEmailVerification(idToken: String) async throws {
        let body = FirebaseOobRequest(requestType: "VERIFY_EMAIL", email: nil, idToken: idToken)
        _ = try await post(identity("accounts:sendOobCode"), body: try JSONEncoder().encode(body))
    }

    /// A new ID token for the session; `AccountError.signInAgain` when the refresh token is no longer valid
    public func refresh(_ session: AuthSession, now: Date = Date()) async throws -> AuthSession {
        let body = FirebaseRefreshRequest(grantType: "refresh_token", refreshToken: session.refreshToken)
        let data = try await post("\(endpoints.tokenURL)/token?key=\(endpoints.apiKey)", body: try JSONEncoder().encode(body))
        guard let answer = try? JSONDecoder().decode(FirebaseRefreshResponse.self, from: data) else {
            throw AccountError.invalidResponse
        }
        var fresh = session
        fresh.idToken = answer.idToken
        fresh.refreshToken = answer.refreshToken
        fresh.expiresAt = AuthSession.expiry(answer.expiresIn, from: now)
        return fresh
    }

    /// Removes the user from Firebase (after the account Worker deleted the data)
    public func deleteUser(idToken: String) async throws {
        _ = try await post(identity("accounts:delete"), body: try JSONEncoder().encode(FirebaseIdTokenRequest(idToken: idToken)))
    }

    /// Revokes the Apple token with the authorization code of a fresh Sign in
    /// with Apple (Apple requires this when the account is deleted). Firebase's v2 API.
    public func revokeAppleToken(idToken: String, authorizationCode: String) async throws {
        let body = FirebaseRevokeRequest(idToken: idToken, providerId: "apple.com", tokenType: "CODE", token: authorizationCode)
        let base = endpoints.identityURL.replacingOccurrences(of: "/v1", with: "/v2")
        _ = try await post("\(base)/accounts:revokeToken?key=\(endpoints.apiKey)", body: try JSONEncoder().encode(body))
    }

    private func identity(_ method: String) -> String {
        "\(endpoints.identityURL)/\(method)?key=\(endpoints.apiKey)"
    }

    private func signIn(_ method: String, body: Data, email: String, provider: String, now: Date) async throws -> AuthSession {
        let data = try await post(identity(method), body: body)
        guard let answer = try? JSONDecoder().decode(FirebaseSignInResponse.self, from: data) else {
            throw AccountError.invalidResponse
        }
        return AuthSession(uid: answer.localId, email: answer.email ?? email, idToken: answer.idToken,
                           refreshToken: answer.refreshToken, expiresAt: AuthSession.expiry(answer.expiresIn, from: now),
                           provider: provider)
    }

    /// The answer's body for a 2xx; Firebase's error as an `AccountError` otherwise
    private func post(_ address: String, body: Data) async throws -> Data {
        guard !endpoints.apiKey.isEmpty, let url = URL(string: address) else { throw AccountError.notConfigured }
        let response: AITransportResponse
        do {
            response = try await transport.send(method: "POST", url: url, headers: ["Content-Type": "application/json"], body: body)
        } catch {
            throw AccountError.noConnection
        }
        if response.status >= 200 && response.status < 300 { return response.body }
        if let failure = try? JSONDecoder().decode(FirebaseErrorBody.self, from: response.body) {
            throw AccountError.firebase(failure.error.message, status: response.status)
        }
        throw AccountError.server(status: response.status)
    }
}
