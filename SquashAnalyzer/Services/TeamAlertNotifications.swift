import Foundation
import UIKit
import UserNotifications
import SquashAnalyzerCore

/// 4.0, T6: the iPhone side of `TeamAlertFollow` (Core). Whoever takes part in
/// a live team match gets plain notifications from the live server (a
/// teammate's partij started or decided, the result): the permission is asked
/// once, at the first auto-follow, and the APNs device token comes through
/// the app delegate.
@MainActor
final class IOSTeamAlertPlatform: TeamAlertPlatform {
    static let shared = IOSTeamAlertPlatform()

    let platform = "ios"
    /// The same APNs environment as the Live Activities
    var usesSandbox: Bool { ActivityKitLiveFollowPresenter.shared.usesSandbox }

    private var token: String?
    private var waiting: [CheckedContinuation<String?, Never>] = []

    private init() {}

    /// At start: the platform and the store for Core, and a fresh token when
    /// notifications are allowed already (tokens can change between launches)
    func install() {
        TeamAlertFollow.shared.platform = self
        TeamAlertFollow.shared.store = TeamMatchStorage.store
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if Self.allows(settings.authorizationStatus) {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func notificationsAllowed(ask: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined && ask {
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        return Self.allows(status)
    }

    private static func allows(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    func pushToken() async -> String? {
        if let token { return token }
        UIApplication.shared.registerForRemoteNotifications()
        return await withCheckedContinuation { continuation in
            waiting.append(continuation)
            // No answer (no network, a simulator without push): give up after ten seconds
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                self.answer(nil)
            }
        }
    }

    /// From the app delegate: the device token (nil when registering failed)
    func received(_ deviceToken: Data?) {
        guard let deviceToken else {
            answer(nil)
            return
        }
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        let changed = token != nil && token != hex
        token = hex
        answer(hex)
        if changed { Task { await TeamAlertFollow.shared.tokenChanged() } }
    }

    private func answer(_ value: String?) {
        let pending = waiting
        waiting = []
        for continuation in pending { continuation.resume(returning: value) }
    }
}

/// The app delegate, only for push notifications: the APNs device token and
/// how a notification shows while the app is open
final class SquashAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in IOSTeamAlertPlatform.shared.received(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in IOSTeamAlertPlatform.shared.received(nil) }
    }

    /// In the open app: a team match notification shows, unless it is about
    /// the partij this phone scores or filled in (the server may not have
    /// known yet) or the setting was just turned off
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        let info = notification.request.content.userInfo
        guard info["kind"] as? String == "team", let id = info["id"] as? String else { return [.banner, .list, .sound] }
        let slot = (info["slot"] as? Int) ?? (info["slot"] as? NSNumber)?.intValue ?? 0
        let show = await MainActor.run { TeamAlertFollow.shared.shouldShow(teamId: id, slot: slot) }
        return show ? [.banner, .list, .sound] : []
    }
}
