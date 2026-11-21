import Foundation

// "Je team is begonnen" (Gerd-Jan, 21 November 2026): a teammate who does not
// play hears it when someone of the team makes a team match visible for the
// team, also with the app closed. For that the phone leaves its push token
// with the account (PUT /api/v1/me/push); the account Worker signs it up as an
// alerts follower of the new live team match and the live Worker sends the
// notification, followed by the usual ones (a partij started or decided, the
// result). Only for accounts of the same team, only while "Meldingen van je
// teamwedstrijd" is on; the token goes when the setting goes off, on signing
// out and with the account.
//
// "Teamstand vanzelf op je vergrendelscherm" (Gerd-Jan, 21 November 2026): a
// phone that can also says how its lock screen card is started (`start`), and
// the live Worker then starts the team stand there together with the
// notification: nobody has to open the app and tap Volgen.

/// The push token of this phone as the account Worker keeps it
public struct AccountPushToken: Codable, Equatable, Sendable {
    /// "ios" or "android"
    public let platform: String
    public let token: String
    public let sandbox: Bool?
    /// "nl" or "en": the language of the notification
    public let lang: String
    /// The phone's install id for the live server (`LiveDevice`)
    public let device: String?
    /// How the team stand is put on the lock screen when the team starts
    /// (`TeamAlertPlatform.lockScreenStart`); nil: the notification only
    public let start: String?

    public init(platform: String, token: String, sandbox: Bool?, lang: String, device: String?, start: String? = nil) {
        self.platform = platform
        self.token = token
        self.sandbox = sandbox
        self.lang = lang
        self.device = device
        self.start = start
    }
}

/// The account side: `PlayerAccount`, or a fake in tests
@MainActor
public protocol TeamStartAccount: AnyObject {
    /// Someone is signed in and the account has a team (Mijn team)
    func teamStartReady() async -> Bool
    func putTeamStartPush(_ push: AccountPushToken) async -> Bool
    func deleteTeamStartPush(token: String) async -> Bool
}

@MainActor
public final class TeamStartAlerts {
    /// What was sent last: "<token>|<lang>|<day>|<start>". Sent again once a
    /// day, so the server knows the phone is still there (it forgets one after
    /// 60 days), and when the way to start the lock screen card changed.
    static let sentKey = "teamStartPushSent"
    public static let shared = TeamStartAlerts()

    private let defaults: UserDefaults
    private var running = false

    public init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    /// The token the account Worker has of this phone, when it has one
    public var sentToken: String? {
        guard let sent = defaults.string(forKey: TeamStartAlerts.sentKey), !sent.isEmpty else { return nil }
        return sent.components(separatedBy: "|").first
    }

    /// Signed out here: the token is no longer this phone's to keep track of
    public func forgetSent() {
        defaults.removeObject(forKey: TeamStartAlerts.sentKey)
    }

    /// Leaves the push token with the account, or takes it away when the
    /// setting is off or the account has no team. Best effort, tried again at
    /// the next start. Notifications are asked for once (shared with
    /// `TeamAlertFollow`, so nobody is asked twice).
    public func sync(alerts: TeamAlertFollow? = nil, account: (any TeamStartAccount)? = nil, now: Date = Date()) async {
        if running { return }
        running = true
        await syncOnce(alerts: alerts ?? TeamAlertFollow.shared, account: account ?? PlayerAccount.shared, now: now)
        running = false
    }

    private func syncOnce(alerts: TeamAlertFollow, account: any TeamStartAccount, now: Date) async {
        guard let platform = alerts.platform else { return }
        var ready = false
        if alerts.isEnabled { ready = await account.teamStartReady() }
        let previous = sentToken
        if !ready {
            if let previous {
                if await account.deleteTeamStartPush(token: previous) { forgetSent() }
            }
            return
        }
        let asked = defaults.bool(forKey: TeamAlertFollow.askedKey)
        if !asked { defaults.set(true, forKey: TeamAlertFollow.askedKey) }
        let allowed = await platform.notificationsAllowed(ask: !asked)
        guard allowed, let token = await platform.pushToken(), !token.isEmpty else { return }
        let lang = AppLanguage.current.code
        let day = Int(now.timeIntervalSince1970 / 86400.0)
        let start = await platform.lockScreenStart()
        let key = "\(token)|\(lang)|\(day)|\(start ?? "")"
        if defaults.string(forKey: TeamStartAlerts.sentKey) == key { return }
        // A new token: the old one goes first
        if let previous, previous != token { _ = await account.deleteTeamStartPush(token: previous) }
        let push = AccountPushToken(platform: platform.platform, token: token,
                                    sandbox: platform.platform == "ios" ? platform.usesSandbox : nil,
                                    lang: lang, device: LiveDevice.id(in: defaults), start: start)
        if await account.putTeamStartPush(push) { defaults.set(key, forKey: TeamStartAlerts.sentKey) }
    }
}

extension PlayerAccount: TeamStartAccount {
    public func teamStartReady() async -> Bool {
        await teamFindingContext() != nil
    }

    public func putTeamStartPush(_ push: AccountPushToken) async -> Bool {
        guard let context = await teamFindingContext() else { return false }
        return (try? await context.client.setPushToken(token: context.token, push)) != nil
    }

    public func deleteTeamStartPush(token: String) async -> Bool {
        guard let auth = try? await validToken(), let accountClient = try? accountClient() else { return false }
        return (try? await accountClient.removePushToken(token: auth, pushToken: token)) != nil
    }
}
