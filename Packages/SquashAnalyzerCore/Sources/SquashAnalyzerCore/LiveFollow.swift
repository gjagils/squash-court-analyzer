import Foundation
import Observation

// Live score op het vergrendelscherm (feature/live-activity): someone who is
// not at the match opens the live link in the app and follows the score on
// the lock screen. iOS shows a Live Activity, Android a Live Update (16+) or
// an ongoing notification. The app registers a push token with the live
// server (POST /api/live/:id/followers); after every rally the server pushes
// the new snapshot through APNs or FCM, so the app itself need not run.

/// A live match (or a live team match) on a live server
public struct LiveFollowTarget: Codable, Equatable, Hashable, Sendable {
    public let id: String
    /// "https://live.squashanalyzer.com", without a trailing slash
    public let server: String
    /// "team" for a team match (Competitie, /t/<id>); nil for a single match
    public let kind: String?

    public init(id: String, server: String, kind: String? = nil) {
        self.id = id
        self.server = server
        self.kind = kind
    }

    public var isTeam: Bool { kind == "team" }

    /// "/api/live/<id>" or "/api/team/<id>"
    public var apiPath: String { (isTeam ? "/api/team/" : "/api/live/") + id }

    /// squashanalyzer://volg#<id> (team: #team/<id>), with "@<host>" for another server than the default
    public var appLink: String {
        let fragment = (isTeam ? "team/" : "") + id
        if server == LiveFollowLink.defaultServer { return "squashanalyzer://volg#" + fragment }
        return "squashanalyzer://volg#" + fragment + "@" + LiveFollowLink.host(of: server)
    }
}

/// Reads a live link: the viewer page (https://live.squashanalyzer.com/l/<id>,
/// a team match /t/<id>), the app link (squashanalyzer://volg#<id>, #team/<id>,
/// each with an optional @<host>) or the bare id.
/// Only known servers are accepted: the app sends a push token there.
public enum LiveFollowLink {
    /// The same as `LiveFollowLink.defaultServer` (that one is MainActor-bound)
    public static let defaultServer = "https://live.squashanalyzer.com"
    public static let knownHosts: [String] = ["live.squashanalyzer.com", "beta.squashanalyzer.com"]
    /// The test Worker of feature/live-activity: squash-live-dev.<account>.workers.dev
    public static let devHostPrefix = "squash-live-dev."
    public static let devHostSuffix = ".workers.dev"

    public static func isAllowedHost(_ host: String) -> Bool {
        let lower = host.lowercased()
        if knownHosts.contains(lower) { return true }
        return lower.hasPrefix(devHostPrefix) && lower.hasSuffix(devHostSuffix) && !lower.contains("/")
    }

    /// "https://live.squashanalyzer.com" → "live.squashanalyzer.com"
    public static func host(of server: String) -> String {
        var rest = server
        if rest.hasPrefix("https://") { rest = String(rest.dropFirst(8)) }
        var host = ""
        for character in rest {
            if character == "/" { break }
            host += String(character)
        }
        return host
    }

    /// The same ids the server makes: 12 of a-z and 0-9
    public static func isValidId(_ id: String) -> Bool {
        guard id.count == 12 else { return false }
        for character in id {
            if !"abcdefghijklmnopqrstuvwxyz0123456789".contains(character) { return false }
        }
        return true
    }

    public static func parse(_ text: String) -> LiveFollowTarget? {
        var words: [String] = []
        var word = ""
        for character in text {
            if character == " " || character == "\n" || character == "\t" || character == "\r" {
                if !word.isEmpty {
                    words.append(word)
                    word = ""
                }
            } else {
                word += String(character)
            }
        }
        if !word.isEmpty { words.append(word) }
        for item in words {
            if let target = parseWord(trimmedEnd(item)) { return target }
        }
        return nil
    }

    private static func parseWord(_ word: String) -> LiveFollowTarget? {
        if word.hasPrefix("squashanalyzer://volg#") {
            var rest = String(word.dropFirst(22))
            var kind: String? = nil
            if rest.hasPrefix("team/") {
                kind = "team"
                rest = String(rest.dropFirst(5))
            }
            var id = ""
            var host = ""
            var inHost = false
            for character in rest {
                if character == "@" {
                    inHost = true
                } else if inHost {
                    host += String(character)
                } else {
                    id += String(character)
                }
            }
            guard isValidId(id) else { return nil }
            if !inHost { return LiveFollowTarget(id: id, server: LiveFollowLink.defaultServer, kind: kind) }
            guard isAllowedHost(host) else { return nil }
            return LiveFollowTarget(id: id, server: "https://" + host.lowercased(), kind: kind)
        }
        if word.hasPrefix("https://") {
            let host = host(of: word)
            guard isAllowedHost(host) else { return nil }
            let path = String(word.dropFirst(8 + host.count))
            let team = path.hasPrefix("/t/")
            guard path.hasPrefix("/l/") || team else { return nil }
            var id = ""
            for character in path.dropFirst(3) {
                if character == "/" || character == "?" || character == "#" { break }
                id += String(character)
            }
            guard isValidId(id) else { return nil }
            return LiveFollowTarget(id: id, server: "https://" + host.lowercased(), kind: team ? "team" : nil)
        }
        if isValidId(word) { return LiveFollowTarget(id: word, server: LiveFollowLink.defaultServer) }
        return nil
    }

    private static func trimmedEnd(_ text: String) -> String {
        var result = text
        while let last = result.last, ".,;:!?)>\"'".contains(last) {
            result = String(result.dropLast())
        }
        return result
    }
}

/// What GET /api/live/:id answers
public struct LiveFollowState: Codable, Sendable {
    public let snapshot: LiveSnapshot
}

/// One partij on the lock screen of a team match: what the server pushes
/// (APNs content-state, FCM `team`), home player first. Names may be empty.
public struct TeamFollowPartij: Codable, Equatable, Hashable, Sendable {
    public var slot: Int
    public var p1: String
    public var p2: String
    public var bestOf: Int
    public var gamesWon: [Int]
    public var score: [Int]
    public var status: String
    public var winner: Int?
    /// "retired" or "walkover"
    public var end: String?

    public init(slot: Int, p1: String, p2: String, bestOf: Int, gamesWon: [Int], score: [Int], status: String,
                winner: Int? = nil, end: String? = nil) {
        self.slot = slot
        self.p1 = p1
        self.p2 = p2
        self.bestOf = bestOf
        self.gamesWon = gamesWon
        self.score = score
        self.status = status
        self.winner = winner
        self.end = end
    }

    /// Decided as the server counts it: a winner, finished, given up or not played
    public var isDecided: Bool {
        winner != nil || status == "finished" || end == "retired" || end == "walkover"
    }

    /// Being played now
    public var isLive: Bool { !isDecided && (status == "playing" || status == "between") }

    /// 1 home, 2 away, 0 not known
    public var winnerSide: Int {
        if let winner { return winner }
        guard isDecided, gamesWon.count == 2 else { return 0 }
        if gamesWon[0] > gamesWon[1] { return 1 }
        if gamesWon[1] > gamesWon[0] { return 2 }
        return 0
    }
}

/// The lock screen stand of a team match (the server's push payload)
public struct TeamFollowStand: Codable, Equatable, Hashable, Sendable {
    public var home: String
    public var away: String
    /// Only the slots that have a partij, by slot
    public var partijen: [TeamFollowPartij]

    public init(home: String, away: String, partijen: [TeamFollowPartij]) {
        self.home = home
        self.away = away
        self.partijen = partijen
    }

    /// The stand as GET /api/team/:id has it
    public init(state: TeamLiveState) {
        home = state.team.home
        away = state.team.away
        var list: [TeamFollowPartij] = []
        for slot in 1...4 {
            guard let partij = state.partijen[String(slot)] else { continue }
            list.append(TeamFollowPartij(slot: slot, p1: partij.p1, p2: partij.p2, bestOf: partij.bestOf,
                                         gamesWon: partij.gamesWon, score: partij.score,
                                         status: partij.status.rawValue, winner: partij.winner, end: partij.end))
        }
        partijen = list
    }

    public func partij(_ slot: Int) -> TeamFollowPartij? {
        for partij in partijen where partij.slot == slot { return partij }
        return nil
    }

    /// Games won by home and away over all partijen, as the team page counts them
    public var homeGames: Int {
        var total = 0
        for partij in partijen where partij.gamesWon.count == 2 { total += partij.gamesWon[0] }
        return total
    }

    public var awayGames: Int {
        var total = 0
        for partij in partijen where partij.gamesWon.count == 2 { total += partij.gamesWon[1] }
        return total
    }

    public var decidedCount: Int {
        var count = 0
        for partij in partijen where partij.isDecided { count += 1 }
        return count
    }

    /// All four partijen decided
    public var isFinished: Bool { decidedCount == 4 }

    /// "Delft 8 E2" for a partij without a name
    public func name(_ partij: TeamFollowPartij, side: Int) -> String {
        let given = side == 1 ? partij.p1 : partij.p2
        if !given.isEmpty { return given }
        return (side == 1 ? home : away) + " E" + String(partij.slot)
    }
}

/// The body of POST and DELETE /api/live/:id/followers
public struct LiveFollowerRegistration: Codable, Equatable, Sendable {
    /// "ios" or "android"
    public let platform: String
    public let token: String
    /// iOS: a development build gets its pushes from the APNs sandbox
    public let sandbox: Bool?
    /// A notification when a game (team match: a partij) is won and at the result
    public let alerts: Bool?
    /// The app's language, "nl" or "en" (`AppLanguage.code`), for the texts of
    /// the pushes; only when following, not when forgetting
    public let lang: String?

    public init(platform: String, token: String, sandbox: Bool? = nil, alerts: Bool? = nil, lang: String? = nil) {
        self.platform = platform
        self.token = token
        self.sandbox = sandbox
        self.alerts = alerts
        self.lang = lang
    }
}

public enum LiveFollowError: Error, Equatable {
    case noTransport
    case noPresenter
    case noConnection
    /// The match is over or the link is wrong (404)
    case notFound
    /// This server cannot push to this platform (503)
    case pushUnavailable
    /// The phone does not allow it (Live Activities or notifications off)
    case notAllowed
    case refused(status: Int)

    /// What the app tells the user (iOS and Android)
    public var message: String {
        switch self {
        case .noTransport, .noPresenter:
            return L10n.text("Deze versie van de app kan de stand nog niet op het vergrendelscherm zetten.")
        case .noConnection:
            return L10n.text("Geen verbinding met de live-server. Controleer de internetverbinding en probeer het opnieuw.")
        case .notFound:
            return L10n.text("Deze wedstrijd is afgelopen of de link klopt niet.")
        case .pushUnavailable:
            return L10n.text("Deze server kan de stand nog niet naar je telefoon sturen.")
        case .notAllowed:
            return L10n.text("Je telefoon staat het niet toe. Zet Live Activities (iPhone) of meldingen (Android) aan voor SquashAnalyzer in de instellingen van je telefoon.")
        case .refused:
            return L10n.text("Volgen lukte niet. Probeer het later opnieuw.")
        }
    }
}

/// The platform part: shows the match on the lock screen. iOS: a Live
/// Activity whose push token arrives later through `LiveFollow.tokenChanged`;
/// Android: a notification, with the device's FCM token.
@MainActor
public protocol LiveFollowPresenter: AnyObject {
    /// "ios" or "android"
    var platform: String { get }
    /// iOS development builds: APNs sandbox
    var usesSandbox: Bool { get }
    /// Shows the first state on the lock screen. Throws `LiveFollowError.notAllowed`
    /// when the phone does not allow it. The token for the server arrives through
    /// `LiveFollow.shared.tokenChanged(_:for:)` (also when it changes later).
    func start(_ target: LiveFollowTarget, snapshot: LiveSnapshot) async throws
    /// The same for a team match (`target.isTeam`)
    func startTeam(_ target: LiveFollowTarget, stand: TeamFollowStand) async throws
    /// Takes the match off the lock screen
    func stop(_ target: LiveFollowTarget) async
}

/// The live matches this phone follows on the lock screen
@MainActor
@Observable
public final class LiveFollow {
    public static let shared = LiveFollow()

    /// Instellingen: "Stand op vergrendelscherm" for the match this phone is
    /// scoring (on by default)
    public static let ownMatchKey = "liveLockScreenOwnMatch"
    /// Instellingen: "Melding bij elke game" (team match: each partij) and at
    /// the result, like a goal in a football app; on by default
    public static let alertsKey = "liveLockScreenAlerts"

    /// Sent with every registration; `setAlerts` changes it for the followed matches too
    public var alerts: Bool = true

    public var transport: (any LiveTransport)? = nil
    public var presenter: (any LiveFollowPresenter)? = nil
    public private(set) var following: [LiveFollowTarget] = []
    /// Why the last followed match came off the lock screen again (the server
    /// refused its push token), for the screen that started following it
    public private(set) var lastError: LiveFollowError? = nil
    /// The last token sent per match id, so the same one is not sent twice
    private var tokens: [String: String] = [:]
    /// "Jan – Piet" per match id, for the list of followed matches
    private var titles: [String: String] = [:]

    public init(transport: (any LiveTransport)? = nil) {
        self.transport = transport
    }

    public func isFollowing(_ target: LiveFollowTarget) -> Bool { following.contains(target) }

    /// "Jan – Piet", once the state was read (or restored with a title)
    public func title(of target: LiveFollowTarget) -> String? { titles[target.id] }

    /// Reads the current state and puts the match on the lock screen
    public func follow(_ target: LiveFollowTarget) async throws {
        lastError = nil
        guard let transport else { throw LiveFollowError.noTransport }
        guard let presenter else { throw LiveFollowError.noPresenter }
        guard let url = URL(string: target.server + target.apiPath) else { throw LiveFollowError.notFound }
        let response: AITransportResponse
        do {
            response = try await transport.send(method: "GET", url: url, headers: [:], body: nil)
        } catch {
            throw LiveFollowError.noConnection
        }
        if response.status == 404 { throw LiveFollowError.notFound }
        guard response.status == 200 else { throw LiveFollowError.refused(status: response.status) }
        if target.isTeam {
            guard let state = try? JSONDecoder().decode(TeamLiveState.self, from: response.body) else {
                throw LiveFollowError.refused(status: response.status)
            }
            let stand = TeamFollowStand(state: state)
            try await presenter.startTeam(target, stand: stand)
            titles[target.id] = stand.home + " – " + stand.away
        } else {
            guard let state = try? JSONDecoder().decode(LiveFollowState.self, from: response.body) else {
                throw LiveFollowError.refused(status: response.status)
            }
            try await presenter.start(target, snapshot: state.snapshot)
            titles[target.id] = state.snapshot.p1 + " – " + state.snapshot.p2
        }
        if !following.contains(target) { following.append(target) }
    }

    /// The platform has a (new) push token for this match: tell the server.
    /// A refused registration takes the match off the lock screen again.
    public func tokenChanged(_ token: String, for target: LiveFollowTarget) async {
        guard tokens[target.id] != token else { return }
        do {
            try await register(token, for: target)
            tokens[target.id] = token
        } catch {
            // Without pushes the lock screen would show a stand that never changes
            lastError = (error as? LiveFollowError) ?? LiveFollowError.noConnection
            await stopFollowing(target)
        }
    }

    /// POST /api/live/:id/followers
    public func register(_ token: String, for target: LiveFollowTarget) async throws {
        guard let transport, let presenter else { throw LiveFollowError.noTransport }
        guard let url = URL(string: target.server + target.apiPath + "/followers") else { throw LiveFollowError.notFound }
        let registration = LiveFollowerRegistration(platform: presenter.platform, token: token,
                                                    sandbox: presenter.platform == "ios" ? presenter.usesSandbox : nil,
                                                    alerts: alerts, lang: AppLanguage.current.code)
        let body = try JSONEncoder().encode(registration)
        let response: AITransportResponse
        do {
            response = try await transport.send(method: "POST", url: url, headers: ["Content-Type": "application/json"], body: body)
        } catch {
            throw LiveFollowError.noConnection
        }
        if response.status == 404 { throw LiveFollowError.notFound }
        if response.status == 503 { throw LiveFollowError.pushUnavailable }
        guard response.status == 201 || response.status == 204 || response.status == 200 else {
            throw LiveFollowError.refused(status: response.status)
        }
    }

    /// Stop following: off the lock screen, and the server forgets the token
    public func unfollow(_ target: LiveFollowTarget) async {
        let token = tokens[target.id]
        await stopFollowing(target)
        await forgetOnServer(token, for: target)
    }

    /// The lock screen ended the match by itself: the server's last push (the
    /// result, which stays on the lock screen for a while) or the user swiped
    /// it away. Forgotten here and on the server, but not taken off the lock
    /// screen: that would remove the result at once.
    public func ended(_ target: LiveFollowTarget) async {
        let token = tokens[target.id]
        forget(target)
        await forgetOnServer(token, for: target)
    }

    /// DELETE /api/live/:id/followers, best effort (the session may be gone already)
    private func forgetOnServer(_ token: String?, for target: LiveFollowTarget) async {
        guard let token, let transport, let presenter,
              let url = URL(string: target.server + target.apiPath + "/followers") else { return }
        let registration = LiveFollowerRegistration(platform: presenter.platform, token: token)
        guard let body = try? JSONEncoder().encode(registration) else { return }
        _ = try? await transport.send(method: "DELETE", url: url, headers: ["Content-Type": "application/json"], body: body)
    }

    /// "Melding bij elke game" changed: from now on, and for the matches this
    /// phone follows (the server keeps the setting per registration)
    public func setAlerts(_ on: Bool) async {
        alerts = on
        for target in following {
            guard let token = tokens[target.id] else { continue }
            try? await register(token, for: target)
        }
    }

    /// A match the platform still shows on the lock screen after a restart of
    /// the app (iOS: a running Live Activity): followed again without asking
    /// the server; its token comes back through `tokenChanged`
    public func restore(_ target: LiveFollowTarget, title: String? = nil) {
        if let title { titles[target.id] = title }
        if !following.contains(target) { following.append(target) }
    }

    /// The match ended or the user dismissed it on the lock screen: forget it here
    public func forget(_ target: LiveFollowTarget) {
        following.removeAll { item in item == target }
        tokens[target.id] = nil
        titles[target.id] = nil
    }

    private func stopFollowing(_ target: LiveFollowTarget) async {
        forget(target)
        await presenter?.stop(target)
    }
}
