import Foundation
import Observation

// Live score op het vergrendelscherm (feature/live-activity): someone who is
// not at the match opens the live link in the app and follows the score on
// the lock screen. iOS shows a Live Activity, Android a Live Update (16+) or
// an ongoing notification. The app registers a push token with the live
// server (POST /api/live/:id/followers); after every rally the server pushes
// the new snapshot through APNs or FCM, so the app itself need not run.

/// A live match on a live server
public struct LiveFollowTarget: Codable, Equatable, Hashable, Sendable {
    public let id: String
    /// "https://live.squashanalyzer.com", without a trailing slash
    public let server: String

    public init(id: String, server: String) {
        self.id = id
        self.server = server
    }

    /// squashanalyzer://volg#<id>, with "@<host>" for another server than the default
    public var appLink: String {
        if server == LiveFollowLink.defaultServer { return "squashanalyzer://volg#" + id }
        return "squashanalyzer://volg#" + id + "@" + LiveFollowLink.host(of: server)
    }
}

/// Reads a live link: the viewer page (https://live.squashanalyzer.com/l/<id>),
/// the app link (squashanalyzer://volg#<id> or #<id>@<host>) or the bare id.
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
            let rest = String(word.dropFirst(22))
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
            if !inHost { return LiveFollowTarget(id: id, server: LiveFollowLink.defaultServer) }
            guard isAllowedHost(host) else { return nil }
            return LiveFollowTarget(id: id, server: "https://" + host.lowercased())
        }
        if word.hasPrefix("https://") {
            let host = host(of: word)
            guard isAllowedHost(host) else { return nil }
            let path = String(word.dropFirst(8 + host.count))
            guard path.hasPrefix("/l/") else { return nil }
            var id = ""
            for character in path.dropFirst(3) {
                if character == "/" || character == "?" || character == "#" { break }
                id += String(character)
            }
            guard isValidId(id) else { return nil }
            return LiveFollowTarget(id: id, server: "https://" + host.lowercased())
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

/// The body of POST and DELETE /api/live/:id/followers
public struct LiveFollowerRegistration: Codable, Equatable, Sendable {
    /// "ios" or "android"
    public let platform: String
    public let token: String
    /// iOS: a development build gets its pushes from the APNs sandbox
    public let sandbox: Bool?

    public init(platform: String, token: String, sandbox: Bool? = nil) {
        self.platform = platform
        self.token = token
        self.sandbox = sandbox
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
            return "Deze versie van de app kan de stand nog niet op het vergrendelscherm zetten."
        case .noConnection:
            return "Geen verbinding met de live-server. Controleer de internetverbinding en probeer het opnieuw."
        case .notFound:
            return "Deze wedstrijd is afgelopen of de link klopt niet."
        case .pushUnavailable:
            return "Deze server kan de stand nog niet naar je telefoon sturen."
        case .notAllowed:
            return "Je telefoon staat het niet toe. Zet Live Activities (iPhone) of meldingen (Android) aan voor SquashAnalyzer in de instellingen van je telefoon."
        case .refused:
            return "Volgen lukte niet. Probeer het later opnieuw."
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

    public var transport: (any LiveTransport)? = nil
    public var presenter: (any LiveFollowPresenter)? = nil
    public private(set) var following: [LiveFollowTarget] = []
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
        guard let transport else { throw LiveFollowError.noTransport }
        guard let presenter else { throw LiveFollowError.noPresenter }
        guard let url = URL(string: target.server + "/api/live/" + target.id) else { throw LiveFollowError.notFound }
        let response: AITransportResponse
        do {
            response = try await transport.send(method: "GET", url: url, headers: [:], body: nil)
        } catch {
            throw LiveFollowError.noConnection
        }
        if response.status == 404 { throw LiveFollowError.notFound }
        guard response.status == 200, let state = try? JSONDecoder().decode(LiveFollowState.self, from: response.body) else {
            throw LiveFollowError.refused(status: response.status)
        }
        try await presenter.start(target, snapshot: state.snapshot)
        titles[target.id] = state.snapshot.p1 + " – " + state.snapshot.p2
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
            await stopFollowing(target)
        }
    }

    /// POST /api/live/:id/followers
    public func register(_ token: String, for target: LiveFollowTarget) async throws {
        guard let transport, let presenter else { throw LiveFollowError.noTransport }
        guard let url = URL(string: target.server + "/api/live/" + target.id + "/followers") else { throw LiveFollowError.notFound }
        let registration = LiveFollowerRegistration(platform: presenter.platform, token: token,
                                                    sandbox: presenter.platform == "ios" ? presenter.usesSandbox : nil)
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
        guard let token, let transport, let presenter,
              let url = URL(string: target.server + "/api/live/" + target.id + "/followers") else { return }
        let registration = LiveFollowerRegistration(platform: presenter.platform, token: token)
        guard let body = try? JSONEncoder().encode(registration) else { return }
        _ = try? await transport.send(method: "DELETE", url: url, headers: ["Content-Type": "application/json"], body: body)
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
