import Foundation

// 4.0, T6 (Gerd-Jan, 10 November 2026: "Vanzelf volgen bij meedoen"): whoever
// starts or joins a live team match follows it with plain notifications, not
// a Live Activity or lock screen card. The live Worker sends one when a
// teammate's partij starts ("E2 begonnen: Paul – Jan"), when a partij is
// decided and at the result; never per rally or game, and never about a
// partij this phone wrote itself (every write carries `LiveDevice.header`).
// Instellingen → Live meekijken can turn it off (`enabledKey`, on by default).
//
// The phone registers as an "alerts" follower of each live team match on it
// (POST /api/team/:id/followers with `mode: "alerts"`) and forgets the ones
// that are no longer live here (left, stopped, deleted, a day old). The
// platform gives the push token: iOS a regular APNs device token, Android
// its FCM token.

/// The phone's install id for the live server: random, made once, never
/// anything personal. Partijen written with it are this phone's own.
public enum LiveDevice {
    public static let storageKey = "liveDeviceId"
    /// The request header every write to a team match carries
    public static let header = "X-Squash-Device"

    public static func id(in defaults: UserDefaults = UserDefaults.standard) -> String {
        if let stored = defaults.string(forKey: LiveDevice.storageKey), !stored.isEmpty { return stored }
        let made = UUID().uuidString.lowercased()
        defaults.set(made, forKey: LiveDevice.storageKey)
        return made
    }
}

/// One live team match this phone is registered for, with what it sent
public struct TeamAlertRegistration: Codable, Equatable, Sendable {
    public let teamId: String
    /// "https://live.squashanalyzer.com"
    public let server: String
    public let token: String
    /// "nl" or "en": the language of the notifications
    public let lang: String

    public init(teamId: String, server: String, token: String, lang: String) {
        self.teamId = teamId
        self.server = server
        self.token = token
        self.lang = lang
    }
}

/// The body of POST and DELETE /api/team/:id/followers for an alerts follower
public struct TeamAlertFollowerBody: Codable, Equatable, Sendable {
    public let platform: String
    public let token: String
    public let sandbox: Bool?
    /// Always "alerts"
    public let mode: String
    public let device: String?
    public let lang: String?
}

/// The platform part: notification permission and the push token
@MainActor
public protocol TeamAlertPlatform: AnyObject {
    /// "ios" or "android"
    var platform: String { get }
    /// iOS development builds get their pushes from the APNs sandbox
    var usesSandbox: Bool { get }
    /// Whether the phone shows notifications of the app; with `ask` the user
    /// is asked first when they have not answered yet (once, at the first auto-follow)
    func notificationsAllowed(ask: Bool) async -> Bool
    /// The token for plain notifications, nil when there is none (no network,
    /// no Google Play services, a simulator)
    func pushToken() async -> String?
}

/// The live team matches this phone follows with notifications
@MainActor
public final class TeamAlertFollow {
    /// Instellingen → Live meekijken: "Meldingen van je teamwedstrijd", on by default
    public static let enabledKey = "teamMatchAlerts"
    static let askedKey = "teamMatchAlertsAsked"
    static let storageKey = "teamMatchAlertFollows"
    public static let shared = TeamAlertFollow()

    public var platform: (any TeamAlertPlatform)? = nil
    /// Set by tests; otherwise the transport of `LiveShare`
    public var transport: (any LiveTransport)? = nil
    /// The team matches on this phone (the app sets it at start)
    public var store: (any TeamMatchStore)? = nil
    /// Set by tests; otherwise the server of `TeamLive`
    public var server: String? = nil

    private let defaults: UserDefaults
    private var running = false
    /// The newest list asked for while a sync was running
    private var pending: [TeamMatch]? = nil
    /// The team matches of the last sync, for `shouldShow`
    private var known: [TeamMatch] = []

    public init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    /// The setting (on when never changed)
    public var isEnabled: Bool {
        if defaults.object(forKey: TeamAlertFollow.enabledKey) == nil { return true }
        return defaults.bool(forKey: TeamAlertFollow.enabledKey)
    }

    /// What this phone is registered for now
    public var registrations: [TeamAlertRegistration] {
        guard let text = defaults.string(forKey: TeamAlertFollow.storageKey),
              let data = text.data(using: String.Encoding.utf8),
              let list = try? JSONDecoder().decode([TeamAlertRegistration].self, from: data) else { return [] }
        return list
    }

    private func save(_ list: [TeamAlertRegistration]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(String(data: data, encoding: String.Encoding.utf8), forKey: TeamAlertFollow.storageKey)
    }

    private var activeTransport: (any LiveTransport)? { transport ?? LiveShare.shared.transport }
    private var activeServer: String { server ?? TeamLive.shared.baseURL }

    /// The live team matches to follow: live here and probably still on the server
    public static func wanted(_ matches: [TeamMatch], now: Date = Date()) -> [String] {
        var ids: [String] = []
        for match in matches where match.isProbablyLive(now: now) {
            if let id = match.liveId, !ids.contains(id) { ids.append(id) }
        }
        return ids
    }

    /// Reads the team matches and follows what is live (best effort)
    public func refresh() async {
        guard let store else { return }
        guard let matches = try? await store.loadAll() else { return }
        await sync(matches: matches)
    }

    /// A team match was saved or deleted (the stores call it): follow anew in the background
    public func matchesChanged() {
        Task { await self.refresh() }
    }

    /// Follows the live team matches in `matches` and forgets the others.
    /// One at a time; a call during a sync runs after it with the newest list.
    public func sync(matches: [TeamMatch], now: Date = Date()) async {
        if running {
            pending = matches
            return
        }
        running = true
        var next: [TeamMatch]? = matches
        while let list = next {
            pending = nil
            await syncOnce(list, now: now)
            next = pending
        }
        running = false
    }

    private func syncOnce(_ matches: [TeamMatch], now: Date) async {
        known = matches
        let server = activeServer
        let lang = AppLanguage.current.code
        var wanted: [String] = []
        if isEnabled && platform != nil && activeTransport != nil {
            wanted = TeamAlertFollow.wanted(matches, now: now)
        }
        // Forget what is no longer live here (or on another server)
        var kept: [TeamAlertRegistration] = []
        for registration in registrations {
            if wanted.contains(registration.teamId) && registration.server == server {
                kept.append(registration)
            } else {
                await forget(registration)
            }
        }
        save(kept)
        guard let platform, !wanted.isEmpty else { return }
        var allSent = true
        for id in wanted {
            var sent = false
            for registration in kept where registration.teamId == id && registration.lang == lang { sent = true }
            if !sent { allSent = false }
        }
        // Asked once, the first time there is something to follow
        let asked = defaults.bool(forKey: TeamAlertFollow.askedKey)
        if !asked { defaults.set(true, forKey: TeamAlertFollow.askedKey) }
        let allowed = await platform.notificationsAllowed(ask: !asked)
        guard allowed, let token = await platform.pushToken(), !token.isEmpty else { return }
        if allSent {
            var sameToken = true
            for registration in kept where registration.token != token { sameToken = false }
            if sameToken { return }
        }
        var result: [TeamAlertRegistration] = []
        for id in wanted {
            var existing: TeamAlertRegistration? = nil
            for registration in kept where registration.teamId == id { existing = registration }
            if let existing, existing.token == token, existing.lang == lang {
                result.append(existing)
                continue
            }
            // A new token: the old one goes first
            if let existing, existing.token != token { await forget(existing) }
            let registration = TeamAlertRegistration(teamId: id, server: server, token: token, lang: lang)
            if await register(registration, platform: platform) { result.append(registration) }
        }
        save(result)
    }

    /// A new push token from the platform: registered again
    public func tokenChanged() async {
        await refresh()
    }

    /// POST /api/team/:id/followers; false when it did not get through (tried again at the next sync)
    private func register(_ registration: TeamAlertRegistration, platform: any TeamAlertPlatform) async -> Bool {
        guard let transport = activeTransport,
              let url = URL(string: registration.server + "/api/team/" + registration.teamId + "/followers") else { return false }
        let body = TeamAlertFollowerBody(platform: platform.platform, token: registration.token,
                                         sandbox: platform.platform == "ios" ? platform.usesSandbox : nil,
                                         mode: "alerts", device: LiveDevice.id(in: defaults), lang: registration.lang)
        guard let data = try? JSONEncoder().encode(body) else { return false }
        do {
            let response = try await transport.send(method: "POST", url: url, headers: ["Content-Type": "application/json"], body: data)
            return response.status == 201 || response.status == 200 || response.status == 204
        } catch {
            return false
        }
    }

    /// DELETE /api/team/:id/followers, best effort (the team match may be gone already)
    private func forget(_ registration: TeamAlertRegistration) async {
        guard let transport = activeTransport, let platform,
              let url = URL(string: registration.server + "/api/team/" + registration.teamId + "/followers") else { return }
        let body = TeamAlertFollowerBody(platform: platform.platform, token: registration.token, sandbox: nil,
                                         mode: "alerts", device: nil, lang: nil)
        guard let data = try? JSONEncoder().encode(body) else { return }
        _ = try? await transport.send(method: "DELETE", url: url, headers: ["Content-Type": "application/json"], body: data)
    }

    /// Whether a notification about `slot` (0: the result) of live team match
    /// `teamId` should show while the app is open: not when the setting is
    /// off, and not about a partij this phone scores or filled in (the server
    /// may not have known that yet)
    public func shouldShow(teamId: String, slot: Int) -> Bool {
        guard isEnabled else { return false }
        if slot == 0 { return true }
        if TeamLive.shared.boundSlots(teamId: teamId).contains(slot) { return false }
        for match in known where match.liveId == teamId {
            let partij = match.partij(slot)
            if partij.hasEntry && partij.fromLive != true { return false }
        }
        return true
    }
}
