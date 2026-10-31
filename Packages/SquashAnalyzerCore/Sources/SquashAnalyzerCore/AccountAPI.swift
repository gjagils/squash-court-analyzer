import Foundation

// 4.0: the client for the account Worker (server/account-worker/src/index.js).
// The signed-in player's calls carry the Firebase ID token ("Bearer …"); a
// phone that sends a match for someone else uses its device key ("Device
// <id>.<key>") and needs no account.

/// The signed-in player's account (GET/POST /api/v1/me)
public struct AccountProfile: Codable, Equatable, Sendable {
    public let playerId: String
    public let name: String
    /// The player code to hand out, so others can send matches (also as QR)
    public let code: String
    public let sbnPath: String?
    public let birthYear: Int
    public let createdAt: Int64

    public init(playerId: String, name: String, code: String, sbnPath: String?, birthYear: Int, createdAt: Int64) {
        self.playerId = playerId
        self.name = name
        self.code = code
        self.sbnPath = sbnPath
        self.birthYear = birthYear
        self.createdAt = createdAt
    }
}

/// Making the account: "Dit ben ik", the birth year (16+) and the consent
public struct AccountCreation: Codable, Equatable, Sendable {
    public var name: String
    public var birthYear: Int
    public var sbnPath: String?
    public var consent: Bool

    public init(name: String, birthYear: Int, sbnPath: String?, consent: Bool) {
        self.name = name
        self.birthYear = birthYear
        self.sbnPath = sbnPath
        self.consent = consent
    }

    /// The youngest birth year that may make an account in `year` (the Worker checks the same)
    public static func latestBirthYear(in year: Int) -> Int { year - 16 }
}

/// A match on the server: waiting in the inbox, or accepted
public struct AccountServerMatch: Codable, Equatable, Sendable, Identifiable {
    public let matchId: String
    /// "pending" or "accepted"
    public let status: String
    public let senderName: String
    public let fromDevice: String?
    public let playedAt: Int64
    public let receivedAt: Int64
    public let teamKey: String?
    public let opponent: String
    public let summary: AccountMatchSummary
    /// Only for accepted matches (the inbox leaves them out)
    public let rallies: [AccountGame]?

    public var id: String { matchId }

    public init(matchId: String, status: String, senderName: String, fromDevice: String?, playedAt: Int64, receivedAt: Int64,
                teamKey: String?, opponent: String, summary: AccountMatchSummary, rallies: [AccountGame]?) {
        self.matchId = matchId
        self.status = status
        self.senderName = senderName
        self.fromDevice = fromDevice
        self.playedAt = playedAt
        self.receivedAt = receivedAt
        self.teamKey = teamKey
        self.opponent = opponent
        self.summary = summary
        self.rallies = rallies
    }

    public var playedDate: Date { Date(timeIntervalSince1970: Double(playedAt) / 1000.0) }

    /// For BadgeEngine; nil without rallies (an inbox entry)
    public var badgeInput: BadgeMatchInput? {
        guard let rallies else { return nil }
        return AccountMatch.badgeInput(summary: summary, rallies: rallies)
    }
}

/// What the app keeps of an award on the server; the id is `AwardValue.awardId`
public struct AccountAwardValue: Codable, Equatable, Sendable {
    /// `BadgeKind.rawValue`
    public var badge: String
    public var matchId: String
    /// Milliseconds since 1970
    public var earnedAt: Int64
    public var opponentName: String
    public var awardedBy: String

    public init(badge: String, matchId: String, earnedAt: Int64, opponentName: String, awardedBy: String) {
        self.badge = badge
        self.matchId = matchId
        self.earnedAt = earnedAt
        self.opponentName = opponentName
        self.awardedBy = awardedBy
    }
}

public struct AccountAward: Codable, Equatable, Sendable {
    public var id: String
    public var value: AccountAwardValue?
    /// Set once deleted (a tombstone, milliseconds since 1970): a merge never brings it back
    public var deletedAt: Int64?

    public init(id: String, value: AccountAwardValue?, deletedAt: Int64?) {
        self.id = id
        self.value = value
        self.deletedAt = deletedAt
    }
}

/// A phone's key for sending matches without an account
public struct AccountDevice: Codable, Equatable, Sendable {
    public let deviceId: String
    public let deviceKey: String

    public init(deviceId: String, deviceKey: String) {
        self.deviceId = deviceId
        self.deviceKey = deviceKey
    }

    var header: String { "Device \(deviceId).\(deviceKey)" }
}

/// Who a match is sent to: a player code, or the SBN player path in a team match
public struct AccountRecipient: Codable, Equatable, Sendable {
    public var code: String?
    public var sbnPath: String?

    public init(code: String? = nil, sbnPath: String? = nil) {
        self.code = code
        self.sbnPath = sbnPath
    }
}

/// POST /api/v1/submissions: the match fields at the top, with who it is for and from
public struct AccountSubmission: Codable, Equatable, Sendable {
    public var matchId: String
    public var playedAt: Int64
    public var opponent: String
    public var teamKey: String?
    public var summary: AccountMatchSummary
    public var rallies: [AccountGame]
    /// Who it is for ("to" in the JSON; not a property name: Kotlin's `encode(to:)` would hide it)
    public var recipient: AccountRecipient
    /// The name the sender uses in the app (the coach name)
    public var senderName: String

    enum CodingKeys: String, CodingKey {
        case matchId, playedAt, opponent, teamKey, summary, rallies, senderName
        case recipient = "to"
    }

    public init(match: AccountMatchUpload, to: AccountRecipient, senderName: String) {
        matchId = match.matchId
        playedAt = match.playedAt
        opponent = match.opponent
        teamKey = match.teamKey
        summary = match.summary
        rallies = match.rallies
        recipient = to
        self.senderName = senderName
    }
}

struct AccountMatchList: Codable {
    let matches: [AccountServerMatch]
}

struct AccountUploadList: Codable {
    let matches: [AccountMatchUpload]
}

struct AccountAwardList: Codable {
    let awards: [AccountAward]
}

struct AccountAnswer: Codable {
    let use: Bool
    let block: Bool?
}

struct AccountWorkerError: Codable {
    let error: String
}

/// The account Worker's API
public struct AccountClient: Sendable {
    public let baseURL: String
    public let transport: any LiveTransport

    public init(baseURL: String, transport: any LiveTransport) {
        self.baseURL = baseURL
        self.transport = transport
    }

    // MARK: Signed in

    /// The account, or nil when this Firebase user has none yet
    public func me(token: String) async throws -> AccountProfile? {
        let response = try await send("GET", "/api/v1/me", auth: "Bearer \(token)", body: nil)
        if response.status == 404 { return nil }
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountProfile.self, from: response.body) else { throw AccountError.invalidResponse }
        return value
    }

    public func createAccount(token: String, _ creation: AccountCreation) async throws -> AccountProfile {
        let response = try await send("POST", "/api/v1/me", auth: "Bearer \(token)", body: try JSONEncoder().encode(creation))
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountProfile.self, from: response.body) else { throw AccountError.invalidResponse }
        return value
    }

    /// Everything of the player goes, at once. Revoke the Apple token before this.
    public func deleteAccount(token: String) async throws {
        let response = try await send("DELETE", "/api/v1/me", auth: "Bearer \(token)", body: nil)
        try check(response)
    }

    /// Matches others sent, waiting for an answer (without rallies)
    public func inbox(token: String) async throws -> [AccountServerMatch] {
        let response = try await send("GET", "/api/v1/me/inbox", auth: "Bearer \(token)", body: nil)
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountMatchList.self, from: response.body) else { throw AccountError.invalidResponse }
        return value.matches
    }

    /// Gebruiken (the accepted match comes back, with rallies), or Niet
    /// gebruiken (nil; `block` also refuses that phone from now on)
    public func answer(token: String, matchId: String, use: Bool, block: Bool = false) async throws -> AccountServerMatch? {
        let body = try JSONEncoder().encode(AccountAnswer(use: use, block: block ? true : nil))
        let response = try await send("POST", "/api/v1/me/inbox/\(matchId)", auth: "Bearer \(token)", body: body)
        if !use {
            try check(response)
            return nil
        }
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountServerMatch.self, from: response.body) else { throw AccountError.invalidResponse }
        return value
    }

    /// Accepted matches decided after `since` (milliseconds; 0 for all)
    public func matches(token: String, since: Int64 = 0) async throws -> [AccountServerMatch] {
        let response = try await send("GET", "/api/v1/me/matches?since=\(since)", auth: "Bearer \(token)", body: nil)
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountMatchList.self, from: response.body) else { throw AccountError.invalidResponse }
        return value.matches
    }

    /// Own matches (entered on this phone): they count at once. At most 50 per call.
    public func addOwnMatches(token: String, _ matches: [AccountMatchUpload]) async throws {
        let body = try JSONEncoder().encode(AccountUploadList(matches: matches))
        let response = try await send("POST", "/api/v1/me/matches", auth: "Bearer \(token)", body: body)
        try check(response)
    }

    public func awards(token: String) async throws -> [AccountAward] {
        let response = try await send("GET", "/api/v1/me/awards", auth: "Bearer \(token)", body: nil)
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountAwardList.self, from: response.body) else { throw AccountError.invalidResponse }
        return value.awards
    }

    /// Merges awards; the server's list comes back (tombstones win)
    public func mergeAwards(token: String, _ awards: [AccountAward]) async throws -> [AccountAward] {
        let body = try JSONEncoder().encode(AccountAwardList(awards: awards))
        let response = try await send("PUT", "/api/v1/me/awards", auth: "Bearer \(token)", body: body)
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountAwardList.self, from: response.body) else { throw AccountError.invalidResponse }
        return value.awards
    }

    // MARK: Without an account

    public func createDevice() async throws -> AccountDevice {
        let response = try await send("POST", "/api/v1/devices", auth: nil, body: nil)
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountDevice.self, from: response.body) else { throw AccountError.invalidResponse }
        return value
    }

    /// Puts a match in a player's inbox. The answer is the same whether or not
    /// the player exists; `AccountError.signInAgain` means the device key is no longer known.
    public func submit(device: AccountDevice, _ submission: AccountSubmission) async throws {
        let response = try await send("POST", "/api/v1/submissions", auth: device.header, body: try JSONEncoder().encode(submission))
        try check(response)
    }

    // MARK: Plumbing

    private func send(_ method: String, _ path: String, auth: String?, body: Data?) async throws -> AITransportResponse {
        guard let url = URL(string: baseURL + path) else { throw AccountError.notConfigured }
        var headers: [String: String] = ["Accept": "application/json"]
        if body != nil { headers["Content-Type"] = "application/json" }
        if let auth { headers["Authorization"] = auth }
        do {
            return try await transport.send(method: method, url: url, headers: headers, body: body)
        } catch {
            throw AccountError.noConnection
        }
    }

    private func check(_ response: AITransportResponse) throws {
        if response.status >= 200 && response.status < 300 { return }
        var text = ""
        if let failure = try? JSONDecoder().decode(AccountWorkerError.self, from: response.body) { text = failure.error }
        throw AccountClient.error(status: response.status, text: text)
    }

    /// The Worker's status and error text as an `AccountError`
    static func error(status: Int, text: String) -> AccountError {
        if status == 401 { return AccountError.signInAgain }
        if status == 403 && text == "too young" { return AccountError.tooYoung }
        if status == 409 { return AccountError.sbnPathTaken }
        if status == 400 && text == "consent" { return AccountError.missingConsent }
        if status == 400 && text == "name" { return AccountError.missingName }
        if status == 404 { return AccountError.notFound }
        if status == 429 { return AccountError.tooManyRequests }
        return AccountError.server(status: status)
    }
}
