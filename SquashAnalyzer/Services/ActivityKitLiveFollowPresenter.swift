import ActivityKit
import Foundation
import SquashAnalyzerCore
import SquashAnalyzerUI

/// Live score op het vergrendelscherm on iOS: Live Activities of
/// `LiveScoreAttributes` (drawn by the SquashLiveActivity extension).
///
/// - A followed match (`LiveFollow`): requested with a push token; the live
///   server sends every new stand through APNs, so the app need not run.
/// - The match this phone is scoring ("Stand op vergrendelscherm" in
///   Instellingen): no pushes, updated from `LiveShareSync` after every rally.
@MainActor
final class ActivityKitLiveFollowPresenter: LiveFollowPresenter {
    static let shared = ActivityKitLiveFollowPresenter()

    let platform = "ios"

    /// Pushes to a development build come from the APNs sandbox. The
    /// provisioning profile says which one the build uses; an App Store build
    /// has no profile (production), the simulator uses the sandbox.
    let usesSandbox: Bool = ActivityKitLiveFollowPresenter.readSandbox()

    /// The tasks that watch an activity's token and state, per activity id
    private var observers: [String: [Task<Void, Never>]] = [:]
    /// Own match: the last state, so a closing screen can tell a finished match
    private var ownFinished: Set<String> = []

    private init() {}

    /// Wires the presenter and the scoring hooks, and picks up the activities
    /// that survived a restart of the app
    func install() {
        LiveFollow.shared.transport = URLSessionLiveTransport()
        LiveFollow.shared.presenter = self
        LiveShareSync.localActivity = { matchId, snapshot, startedAt in
            ActivityKitLiveFollowPresenter.shared.showOwn(matchId: matchId, snapshot: snapshot, startedAt: startedAt)
        }
        LiveShareSync.localActivityEnded = { matchId in
            ActivityKitLiveFollowPresenter.shared.endOwn(matchId: matchId)
        }
        restoreRunning()
    }

    // MARK: - Followed matches

    func start(_ target: LiveFollowTarget, snapshot: LiveSnapshot) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw LiveFollowError.notAllowed }
        let state = Self.contentState(snapshot)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60))
        if let running = followed(target) {
            await running.update(content)
            return
        }
        let attributes = LiveScoreAttributes(matchId: target.id, server: target.server, isOwnMatch: false, startedAt: nil)
        let activity: Activity<LiveScoreAttributes>
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: .token)
        } catch {
            throw LiveFollowError.notAllowed
        }
        observe(activity, target: target)
    }

    func stop(_ target: LiveFollowTarget) async {
        for activity in Activity<LiveScoreAttributes>.activities where Self.target(of: activity) == target {
            await activity.end(nil, dismissalPolicy: .immediate)
            cancelObservers(activity.id)
        }
    }

    private func followed(_ target: LiveFollowTarget) -> Activity<LiveScoreAttributes>? {
        Activity<LiveScoreAttributes>.activities.first { activity in
            Self.target(of: activity) == target && activity.activityState == .active
        }
    }

    /// Hands every (new) push token to the server and forgets the match once
    /// the activity ends: the match finished (the server's "end"), or the user
    /// swiped it away on the lock screen
    private func observe(_ activity: Activity<LiveScoreAttributes>, target: LiveFollowTarget) {
        cancelObservers(activity.id)
        let tokens = Task { @MainActor in
            for await data in activity.pushTokenUpdates {
                let token = data.map { byte in String(format: "%02x", byte) }.joined()
                await LiveFollow.shared.tokenChanged(token, for: target)
            }
        }
        let states = Task { @MainActor in
            for await state in activity.activityStateUpdates {
                if state == .dismissed || state == .ended {
                    // Also tells the server to stop pushing to this token
                    if LiveFollow.shared.isFollowing(target) { await LiveFollow.shared.unfollow(target) }
                    ActivityKitLiveFollowPresenter.shared.cancelObservers(activity.id)
                    return
                }
            }
        }
        observers[activity.id] = [tokens, states]
    }

    private func cancelObservers(_ id: String) {
        for task in observers[id] ?? [] { task.cancel() }
        observers[id] = nil
    }

    /// After a restart: followed matches still on the lock screen are followed
    /// again (their token comes back through `pushTokenUpdates`); an own match
    /// whose scoring screen is gone is taken off
    private func restoreRunning() {
        for activity in Activity<LiveScoreAttributes>.activities {
            if activity.attributes.isOwnMatch {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
                continue
            }
            guard let target = Self.target(of: activity), activity.activityState == .active else { continue }
            let state = activity.content.state
            LiveFollow.shared.restore(target, title: state.p1 + " – " + state.p2)
            observe(activity, target: target)
        }
    }

    // MARK: - The match this phone is scoring

    /// Shows or updates the own match on the lock screen ("Stand op
    /// vergrendelscherm"); a finished match stays for half an hour
    func showOwn(matchId: UUID, snapshot: LiveSnapshot, startedAt: Date?) {
        let id = matchId.uuidString
        let enabled = UserDefaults.standard.object(forKey: LiveFollow.ownMatchKey) as? Bool ?? true
        let running = Activity<LiveScoreAttributes>.activities.first { activity in
            activity.attributes.isOwnMatch && activity.attributes.matchId == id && activity.activityState == .active
        }
        guard enabled else {
            if let running { Task { await running.end(nil, dismissalPolicy: .immediate) } }
            return
        }
        let state = Self.contentState(snapshot)
        let finished = snapshot.status == .finished
        if finished { ownFinished.insert(id) } else { ownFinished.remove(id) }
        let content = ActivityContent(state: state, staleDate: nil)
        if let running {
            Task {
                if finished {
                    await running.end(content, dismissalPolicy: .after(Date().addingTimeInterval(30 * 60)))
                } else {
                    await running.update(content)
                }
            }
            return
        }
        guard !finished, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = LiveScoreAttributes(matchId: id, server: "", isOwnMatch: true, startedAt: startedAt)
        _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    /// The scoring screen closed: a match under way leaves the lock screen
    /// (a finished one stays for its half hour)
    func endOwn(matchId: UUID) {
        let id = matchId.uuidString
        guard !ownFinished.contains(id) else { return }
        for activity in Activity<LiveScoreAttributes>.activities where activity.attributes.isOwnMatch && activity.attributes.matchId == id {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    // MARK: - Helpers

    static func target(of activity: Activity<LiveScoreAttributes>) -> LiveFollowTarget? {
        let attributes = activity.attributes
        guard !attributes.isOwnMatch else { return nil }
        return LiveFollowTarget(id: attributes.matchId, server: attributes.server)
    }

    nonisolated static func contentState(_ snapshot: LiveSnapshot) -> LiveScoreAttributes.ContentState {
        LiveScoreAttributes.ContentState(p1: snapshot.p1, p2: snapshot.p2, bestOf: snapshot.bestOf, games: snapshot.games,
                                         score: snapshot.score, gamesWon: snapshot.gamesWon, server: snapshot.server,
                                         side: snapshot.side, status: snapshot.status.rawValue,
                                         lastPoint: snapshot.lastPoint, winner: snapshot.winner)
    }

    private static func readSandbox() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1) else { return false }
        // The profile is a signed plist; its Entitlements hold aps-environment
        guard let range = text.range(of: "<key>aps-environment</key>") else { return false }
        let rest = text[range.upperBound...].prefix(80)
        return rest.contains("development")
        #endif
    }
}

#if DEBUG
/// Screenshots and simulator checks: `-LiveActivityDemo <state>` puts a made-up
/// own match on the lock screen (playing, gameball, matchball, between, finished)
enum LiveActivityDemo {
    @MainActor
    static func runIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-LiveActivityDemo") else { return }
        let name = index + 1 < arguments.count ? arguments[index + 1] : "playing"
        let snapshot = demoSnapshot(name)
        let matchId = UUID(uuidString: "00000000-0000-0000-0000-00000000DE30") ?? UUID()
        for activity in Activity<LiveScoreAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UserDefaults.standard.set(true, forKey: LiveFollow.ownMatchKey)
            let startedAt = Date().addingTimeInterval(-34 * 60)
            let presenter = ActivityKitLiveFollowPresenter.shared
            guard snapshot.status == .finished else {
                presenter.showOwn(matchId: matchId, snapshot: snapshot, startedAt: startedAt)
                return
            }
            // A finished own match only ends a running activity: start one first
            presenter.showOwn(matchId: matchId, snapshot: demoSnapshot("playing"), startedAt: startedAt)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                presenter.showOwn(matchId: matchId, snapshot: snapshot, startedAt: startedAt)
            }
        }
    }

    static func demoSnapshot(_ name: String) -> LiveSnapshot {
        switch name {
        case "gameball":
            return LiveSnapshot(p1: "Jan", p2: "Piet", bestOf: 5, games: [[11, 8], [6, 11]], score: [10, 7],
                                gamesWon: [1, 1], server: 1, side: "R", status: .playing)
        case "matchball":
            return LiveSnapshot(p1: "Jan", p2: "Piet", bestOf: 5, games: [[11, 8], [6, 11], [11, 9]], score: [10, 9],
                                gamesWon: [2, 1], server: 1, side: "L", status: .playing)
        case "between":
            return LiveSnapshot(p1: "Jan", p2: "Piet", bestOf: 5, games: [[11, 8], [6, 11]], score: [0, 0],
                                gamesWon: [1, 1], server: 2, side: "R", status: .between)
        case "finished":
            return LiveSnapshot(p1: "Jan", p2: "Piet", bestOf: 5, games: [[11, 8], [6, 11], [11, 9], [11, 5]], score: [11, 5],
                                gamesWon: [3, 1], server: 1, side: "R", status: .finished, winner: 1)
        default:
            return LiveSnapshot(p1: "Jan", p2: "Piet", bestOf: 5, games: [[11, 8], [6, 11]], score: [9, 7],
                                gamesWon: [1, 1], server: 1, side: "L", status: .playing)
        }
    }
}
#endif
