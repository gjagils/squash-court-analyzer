import Foundation

// 4.0: the client for the account Worker (server/account-worker/src/index.js).
// The signed-in player's calls carry the Firebase ID token ("Bearer …"); a
// phone that sends a match for someone else uses its device key ("Device
// <id>.<key>") and needs no account.

/// The signed-in player's account (GET/POST /api/v1/me)
public struct AccountProfile: Codable, Equatable, Sendable {
    public let playerId: String
    public let name: String
    /// The player code (older builds sent to it; the screens no longer show it)
    public let code: String
    /// The SBN player ("/league/<uuid>/player/<n>"), set once
    public let sbnPath: String?
    /// The SBN team (`LeagueTeamLink.accountKey`): its matches that wait for a name show up
    public let teamKey: String?
    public let birthYear: Int
    public let createdAt: Int64
    /// The version of your avatar (milliseconds of the upload); nil without one
    public let avatarVersion: Int64?

    public init(playerId: String, name: String, code: String, sbnPath: String?, teamKey: String? = nil, birthYear: Int, createdAt: Int64,
                avatarVersion: Int64? = nil) {
        self.playerId = playerId
        self.name = name
        self.code = code
        self.sbnPath = sbnPath
        self.teamKey = teamKey
        self.birthYear = birthYear
        self.createdAt = createdAt
        self.avatarVersion = avatarVersion
    }

    /// "ABCDE FGHJK": easier to read out and type over
    public static func spaced(_ code: String) -> String {
        var result = ""
        var count = 0
        for character in code {
            if count == 5 { result += " " }
            result += String(character)
            count += 1
        }
        return result
    }
}

/// Making the account: "Dit ben ik", the birth year (16+) and the consent
public struct AccountCreation: Codable, Equatable, Sendable {
    public var name: String
    public var birthYear: Int
    public var sbnPath: String?
    public var teamKey: String?
    public var consent: Bool

    public init(name: String, birthYear: Int, sbnPath: String?, teamKey: String? = nil, consent: Bool) {
        self.name = name
        self.birthYear = birthYear
        self.sbnPath = sbnPath
        self.teamKey = teamKey
        self.consent = consent
    }

    /// The youngest birth year that may make an account in `year` (the Worker checks the same)
    public static func latestBirthYear(in year: Int) -> Int { year - 16 }
}

/// PATCH /api/v1/me: only what is set changes (a name with a typo, "Dit ben ik" later)
public struct AccountUpdate: Codable, Equatable, Sendable {
    public var name: String?
    public var sbnPath: String?
    public var teamKey: String?

    public init(name: String? = nil, sbnPath: String? = nil, teamKey: String? = nil) {
        self.name = name
        self.sbnPath = sbnPath
        self.teamKey = teamKey
    }
}

/// A match on the server: waiting in the inbox, accepted, or (with `name`)
/// one of the own team that waits for "dat ben ik"
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
    /// A team match waiting for a name: the name the sender used ("Gerd Lasso")
    public let name: String?
    /// When it was accepted (milliseconds; accepted matches only): the sync's cursor
    public let decidedAt: Int64?

    public var id: String { matchId }

    public init(matchId: String, status: String, senderName: String, fromDevice: String?, playedAt: Int64, receivedAt: Int64,
                teamKey: String?, opponent: String, summary: AccountMatchSummary, rallies: [AccountGame]?, name: String? = nil,
                decidedAt: Int64? = nil) {
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
        self.name = name
        self.decidedAt = decidedAt
    }

    public var playedDate: Date { Date(timeIntervalSince1970: Double(playedAt) / 1000.0) }

    /// "Van Peter, 30 okt."
    public var inboxTitle: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.current.locale
        formatter.dateFormat = "d MMM"
        let sender = senderName.isEmpty ? L10n.text("onbekende afzender") : senderName
        return L10n.text("Van %@, %@", sender, formatter.string(from: playedDate))
    }

    /// "3-1 tegen Mark · coach" (who entered it: a coach or a referee)
    public var inboxDetail: String {
        let kind = summary.kind == "referee" ? L10n.text("scheidsrechter") : L10n.text("coach")
        return "\(summary.resultLine) · \(kind)"
    }

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

/// Who a match is sent to: an SBN player, the name the sender uses in an SBN
/// team ("Gerd Lasso" in team 3, for teammates to claim), whoever opens a
/// shared link, or a player code (older builds)
public struct AccountRecipient: Codable, Equatable, Sendable {
    public var code: String?
    public var sbnPath: String?
    /// `LeagueTeamLink.accountKey`, with `name`
    public var team: String?
    public var name: String?
    public var link: Bool?

    public init(code: String? = nil, sbnPath: String? = nil, team: String? = nil, name: String? = nil, link: Bool? = nil) {
        self.code = code
        self.sbnPath = sbnPath
        self.team = team
        self.name = name
        self.link = link
    }
}

/// The answer to a submission; a link submission carries the token for the link
public struct AccountSubmitResult: Codable, Equatable, Sendable {
    public let received: String
    public let claimToken: String?

    public init(received: String, claimToken: String?) {
        self.received = received
        self.claimToken = claimToken
    }
}

/// What a teammate's claim taught this phone: its name for a player in that team is this SBN player
public struct AccountLearnedLink: Codable, Equatable, Sendable {
    public let teamKey: String
    /// Lowercased, single spaces (the Worker's name key)
    public let name: String
    public let sbnPath: String

    public init(teamKey: String, name: String, sbnPath: String) {
        self.teamKey = teamKey
        self.name = name
        self.sbnPath = sbnPath
    }
}

struct AccountLinkList: Codable {
    let links: [AccountLearnedLink]
}

struct AccountClaimName: Codable {
    let name: String
}

struct AccountClaimToken: Codable {
    let token: String
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

/// 4.0 (docs/voorstel-teamwedstrijd-vinden-4.0.md): a live team match that a
/// teammate or the opponent registered for an SBN match
public struct TeamLiveListing: Codable, Equatable, Sendable, Identifiable {
    /// `LeagueFixture.id` ("/league/<UUID>/team-match/<n>", the league in capitals)
    public let fixture: String
    /// The team that keeps it
    public let teamName: String
    public let liveId: String
    /// Only for the own team: the invitation key
    public let writeKey: String?
    /// The opponent's key (for the partijen they referee), when it was made with one
    public let refereeKey: String?
    public let starterName: String
    /// Milliseconds since 1970
    public let matchAt: Int64
    /// Kept by our own team
    public let own: Bool

    public var id: String { fixture + "|" + liveId }

    /// Only letters, digits, "-" and "/" (what an SBN match link holds), starting with "/league/"
    public static func isFixture(_ text: String) -> Bool {
        if !text.hasPrefix("/league/") || text.count > 120 { return false }
        let allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-/"
        for character in text where !allowed.contains(character) { return false }
        return true
    }

    public init(fixture: String, teamName: String, liveId: String, writeKey: String?, refereeKey: String?,
                starterName: String, matchAt: Int64, own: Bool) {
        self.fixture = fixture
        self.teamName = teamName
        self.liveId = liveId
        self.writeKey = writeKey
        self.refereeKey = refereeKey
        self.starterName = starterName
        self.matchAt = matchAt
        self.own = own
    }
}

struct TeamLiveListingList: Codable {
    let lives: [TeamLiveListing]
}

/// What `PUT /api/v1/me/team/lives` takes
public struct TeamLiveRegistration: Codable, Equatable, Sendable {
    public var fixture: String
    /// Milliseconds since 1970: the match day
    public var date: Int64
    public var teamName: String
    public var liveId: String
    public var writeKey: String
    public var refereeKey: String?
    /// The live id of a registration whose live team match is gone
    public var replaces: String?

    public init(fixture: String, date: Int64, teamName: String, liveId: String, writeKey: String,
                refereeKey: String? = nil, replaces: String? = nil) {
        self.fixture = fixture
        self.date = date
        self.teamName = teamName
        self.liveId = liveId
        self.writeKey = writeKey
        self.refereeKey = refereeKey
        self.replaces = replaces
    }
}

/// The answer to registering: ours, or the one that was there first (the phone joins that one)
public struct TeamLiveRegistered: Equatable, Sendable {
    public let listing: TeamLiveListing
    public let wasThereFirst: Bool
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

    public func updateAccount(token: String, _ update: AccountUpdate) async throws -> AccountProfile {
        let response = try await send("PATCH", "/api/v1/me", auth: "Bearer \(token)", body: try JSONEncoder().encode(update))
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

    /// Matches of the own team that wait for a name (without rallies)
    public func teamMatches(token: String) async throws -> [AccountServerMatch] {
        let response = try await send("GET", "/api/v1/me/team", auth: "Bearer \(token)", body: nil)
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountMatchList.self, from: response.body) else { throw AccountError.invalidResponse }
        return value.matches
    }

    /// "Dat ben ik": the match counts at once and comes back with its rallies
    public func claimTeamMatch(token: String, matchId: String, name: String) async throws -> AccountServerMatch {
        let body = try JSONEncoder().encode(AccountClaimName(name: name))
        let response = try await send("POST", "/api/v1/me/team/\(matchId)", auth: "Bearer \(token)", body: body)
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountServerMatch.self, from: response.body) else { throw AccountError.invalidResponse }
        return value
    }

    /// A match from a shared link: it counts at once
    public func claimLink(token: String, claimToken: String) async throws -> AccountServerMatch {
        let body = try JSONEncoder().encode(AccountClaimToken(token: claimToken))
        let response = try await send("POST", "/api/v1/me/claim", auth: "Bearer \(token)", body: body)
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

    // MARK: Live team matches to find (4.0)

    /// The live team matches of the own team, and of opponents for these SBN matches (`LeagueFixture.id`)
    public func teamLives(token: String, fixtures: [String]) async throws -> [TeamLiveListing] {
        // A fixture is letters, digits, "-" and "/": all allowed in a query as they are
        // (no percent-encoding: CharacterSet is thin in Skip)
        var query = ""
        for fixture in fixtures.prefix(20) where TeamLiveListing.isFixture(fixture) {
            query += (query.isEmpty ? "" : ",") + fixture
        }
        let response = try await send("GET", "/api/v1/me/team/lives?fixtures=" + query, auth: "Bearer \(token)", body: nil)
        try check(response)
        guard let value = try? JSONDecoder().decode(TeamLiveListingList.self, from: response.body) else { throw AccountError.invalidResponse }
        return value.lives
    }

    /// Registers the own team's live team match; when one was there first, that one comes back
    public func registerTeamLive(token: String, _ registration: TeamLiveRegistration) async throws -> TeamLiveRegistered {
        let response = try await send("PUT", "/api/v1/me/team/lives", auth: "Bearer \(token)",
                                      body: try JSONEncoder().encode(registration))
        if response.status != 409 { try check(response) }
        guard let value = try? JSONDecoder().decode(TeamLiveListing.self, from: response.body) else { throw AccountError.invalidResponse }
        return TeamLiveRegistered(listing: value, wasThereFirst: response.status == 409)
    }

    /// The own registration for this SBN match goes
    public func removeTeamLive(token: String, fixture: String) async throws {
        guard TeamLiveListing.isFixture(fixture) else { return }
        let response = try await send("DELETE", "/api/v1/me/team/lives?fixture=" + fixture, auth: "Bearer \(token)", body: nil)
        try check(response)
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
    @discardableResult
    public func submit(device: AccountDevice, _ submission: AccountSubmission) async throws -> AccountSubmitResult? {
        let response = try await send("POST", "/api/v1/submissions", auth: device.header, body: try JSONEncoder().encode(submission))
        try check(response)
        return try? JSONDecoder().decode(AccountSubmitResult.self, from: response.body)
    }

    /// The names this phone uses that a teammate's claim linked to an SBN player
    public func learnedLinks(device: AccountDevice) async throws -> [AccountLearnedLink] {
        let response = try await send("GET", "/api/v1/devices/links", auth: device.header, body: nil)
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountLinkList.self, from: response.body) else { throw AccountError.invalidResponse }
        return value.links
    }

    // MARK: Account mails (11 November 2026): sent by the Worker through Cirrux

    /// "Bevestig je e-mailadres" for the signed-in user. False when the Worker
    /// cannot send mail (no mail secrets yet, or an older Worker): then Firebase sends.
    public func mailVerify(token: String, lang: String) async throws -> Bool {
        let body = try JSONEncoder().encode(AccountMailRequest(email: "", lang: lang))
        let response = try await send("POST", "/api/v1/mail/verify", auth: "Bearer \(token)", body: body)
        if response.status == 503 || response.status == 404 { return false }
        try check(response)
        return true
    }

    /// "Kies een nieuw wachtwoord"; the same answer whether the address has an account. False: Firebase sends.
    public func mailReset(email: String, lang: String) async throws -> Bool {
        let body = try JSONEncoder().encode(AccountMailRequest(email: email, lang: lang))
        let response = try await send("POST", "/api/v1/mail/reset", auth: nil, body: body)
        if response.status == 503 || response.status == 404 { return false }
        try check(response)
        return true
    }

    /// A new address: the Worker mails a link to it, and the change follows that link
    public func mailChange(token: String, email: String, lang: String) async throws {
        let body = try JSONEncoder().encode(AccountMailRequest(email: email, lang: lang))
        let response = try await send("POST", "/api/v1/mail/change", auth: "Bearer \(token)", body: body)
        if response.status == 503 || response.status == 404 { throw AccountError.mailUnavailable }
        try check(response)
    }

    // MARK: Plumbing

    // MARK: Avatars (Gerd-Jan, 10 November 2026)

    /// Your avatar: a small square JPEG, with consent that whoever picks you as a player may see it
    @discardableResult
    public func setAvatar(token: String, jpeg: Data) async throws -> Int64 {
        let body = try JSONEncoder().encode(AccountAvatarUpload(image: jpeg.base64EncodedString(), consent: true))
        let response = try await send("PUT", "/api/v1/me/avatar", auth: "Bearer \(token)", body: body)
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountAvatarVersion.self, from: response.body) else { throw AccountError.invalidResponse }
        return value.version
    }

    /// Your own avatar; nil without one
    public func ownAvatar(token: String) async throws -> Data? {
        let response = try await send("GET", "/api/v1/me/avatar", auth: "Bearer \(token)", body: nil)
        if response.status == 404 { return nil }
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountAvatarImage.self, from: response.body) else { throw AccountError.invalidResponse }
        return Data(base64Encoded: value.image)
    }

    public func deleteAvatar(token: String) async throws {
        let response = try await send("DELETE", "/api/v1/me/avatar", auth: "Bearer \(token)", body: nil)
        try check(response)
    }

    /// Which of these SBN players have an avatar, and its version
    public func avatarVersions(device: AccountDevice, sbnPaths: [String]) async throws -> [String: Int64] {
        var query = ""
        for path in sbnPaths.prefix(50) where AccountClient.isQuerySafe(path) {
            query += (query.isEmpty ? "?" : "&") + "sbn=" + path
        }
        if query.isEmpty { return [:] }
        let response = try await send("GET", "/api/v1/avatars" + query, auth: device.header, body: nil)
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountAvatarList.self, from: response.body) else { throw AccountError.invalidResponse }
        var result: [String: Int64] = [:]
        for item in value.avatars { result[item.sbnPath] = item.version }
        return result
    }

    /// The photo of one SBN player; nil without one
    public func avatar(device: AccountDevice, sbnPath: String) async throws -> Data? {
        guard AccountClient.isQuerySafe(sbnPath) else { return nil }
        let response = try await send("GET", "/api/v1/avatars/image?sbn=" + sbnPath, auth: device.header, body: nil)
        if response.status == 404 { return nil }
        try check(response)
        guard let value = try? JSONDecoder().decode(AccountAvatarImage.self, from: response.body) else { throw AccountError.invalidResponse }
        return Data(base64Encoded: value.image)
    }

    /// "Foto melden"
    public func reportAvatar(device: AccountDevice, sbnPath: String) async throws {
        let body = try JSONEncoder().encode(AccountAvatarReport(sbnPath: sbnPath))
        let response = try await send("POST", "/api/v1/avatars/report", auth: device.header, body: body)
        try check(response)
    }

    /// Letters, digits, "-", "_" and "/": what an SBN path is made of, fine in a query as it is
    /// (no percent-encoding: CharacterSet is thin in Skip)
    static func isQuerySafe(_ text: String) -> Bool {
        if text.isEmpty || text.count > 200 { return false }
        let allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_/"
        for character in text where !allowed.contains(character) { return false }
        return true
    }

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
        if status == 409 && text == "email taken" { return AccountError.emailInUse }
        if status == 409 && text == "not password" { return AccountError.mailUnavailable }
        if status == 400 && text == "same email" { return AccountError.sameEmail }
        if status == 400 && text == "email" { return AccountError.invalidEmail }
        if status == 409 { return AccountError.sbnPathTaken }
        if status == 400 && text == "consent" { return AccountError.missingConsent }
        if status == 400 && text == "name" { return AccountError.missingName }
        if status == 404 { return AccountError.notFound }
        if status == 429 { return AccountError.tooManyRequests }
        return AccountError.server(status: status)
    }
}

struct AccountMailRequest: Codable {
    let email: String
    let lang: String
}

struct AccountAvatarUpload: Codable {
    let image: String
    let consent: Bool
}

struct AccountAvatarVersion: Codable {
    let version: Int64
}

struct AccountAvatarImage: Codable {
    let image: String
}

struct AccountAvatarItem: Codable {
    let sbnPath: String
    let version: Int64
}

struct AccountAvatarList: Codable {
    let avatars: [AccountAvatarItem]
}

struct AccountAvatarReport: Codable {
    let sbnPath: String
}
