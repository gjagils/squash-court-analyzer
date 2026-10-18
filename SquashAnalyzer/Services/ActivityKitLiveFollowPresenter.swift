import ActivityKit
import Foundation
import UIKit
import SquashAnalyzerCore
import SquashAnalyzerUI

/// Live score op het vergrendelscherm on iOS: Live Activities of
/// `LiveScoreAttributes` and `TeamScoreAttributes` (drawn by the
/// SquashLiveActivity extension).
///
/// - A followed match (`LiveFollow`): requested with a push token; the live
///   server sends every new stand through APNs, so the app need not run.
/// - A followed team match: the same, with the four partijen on one card.
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
    /// Own matches whose photos are in the App Group already
    private var ownPhotosStored: Set<String> = []

    private init() {}

    /// Wires the presenter and the scoring hooks, and picks up the activities
    /// that survived a restart of the app
    func install() {
        LiveFollow.shared.transport = URLSessionLiveTransport()
        LiveFollow.shared.presenter = self
        // "Melding bij elke game" (Instellingen), sent with every registration
        LiveFollow.shared.alerts = UserDefaults.standard.object(forKey: LiveFollow.alertsKey) as? Bool ?? true
        LiveShareSync.localActivity = { matchId, snapshot, startedAt in
            ActivityKitLiveFollowPresenter.shared.showOwn(matchId: matchId, snapshot: snapshot, startedAt: startedAt)
        }
        LiveShareSync.localActivityEnded = { matchId in
            ActivityKitLiveFollowPresenter.shared.endOwn(matchId: matchId)
        }
        LiveShareSync.localActivityPhotos = { matchId, photos in
            ActivityKitLiveFollowPresenter.shared.storeOwnPhotos(matchId: matchId, photos: photos)
        }
        restoreRunning()
        removeUnusedPhotos()
        refreshTeamPhotos()
        // Pushes carry no photos: a followed team match gets the partij photos
        // added since it was followed whenever the app comes to the front
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil,
                                               queue: .main) { _ in
            Task { @MainActor in ActivityKitLiveFollowPresenter.shared.refreshTeamPhotos() }
        }
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
        // The players' photos go to the App Group before the activity appears;
        // a slow download shows the letters first and the photos with the next rally
        removeUnusedPhotos()
        let photos = Task { await Self.downloadPhotos(target) }
        let downloaded = await Self.finished(photos, within: 3)
        let attributes = LiveScoreAttributes(matchId: target.id, server: target.server, isOwnMatch: false, startedAt: nil)
        let activity: Activity<LiveScoreAttributes>
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: .token)
        } catch {
            LiveScorePhotoStore.remove(matchId: target.id)
            throw LiveFollowError.notAllowed
        }
        observe(activity, target: target) { LiveScorePhotoStore.remove(matchId: target.id) }
        if !downloaded {
            Task {
                _ = await photos.value
                await activity.update(activity.content)
            }
        }
    }

    func stop(_ target: LiveFollowTarget) async {
        if target.isTeam {
            for activity in Activity<TeamScoreAttributes>.activities where Self.target(of: activity) == target {
                await activity.end(nil, dismissalPolicy: .immediate)
                cancelObservers(activity.id)
            }
            TeamScorePhotoStore.remove(teamId: target.id)
            return
        }
        for activity in Activity<LiveScoreAttributes>.activities where Self.target(of: activity) == target {
            await activity.end(nil, dismissalPolicy: .immediate)
            cancelObservers(activity.id)
        }
        LiveScorePhotoStore.remove(matchId: target.id)
    }

    /// GET /api/live/:id/photo/1 and 2 (404: no photo), stored as small
    /// thumbnails for the widget. Photos are sent once at the start of a
    /// match, so they are read once when following starts.
    nonisolated static func downloadPhotos(_ target: LiveFollowTarget) async -> Bool {
        for player in [1, 2] {
            guard let url = URL(string: target.server + "/api/live/" + target.id + "/photo/\(player)") else { continue }
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("image/jpeg", forHTTPHeaderField: "Accept")
            let data: Data?
            if let (body, response) = try? await URLSession.shared.data(for: request),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                data = body
            } else {
                data = nil
            }
            LiveScorePhotoStore.store(data, matchId: target.id, player: player)
        }
        return true
    }

    /// Whether `task` finished within `seconds` (it runs on either way)
    static func finished(_ task: Task<Bool, Never>, within seconds: Double) async -> Bool {
        final class Once { var done = false }
        let once = Once()
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                let result = await task.value
                guard !once.done else { return }
                once.done = true
                continuation.resume(returning: result)
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                guard !once.done else { return }
                once.done = true
                continuation.resume(returning: false)
            }
        }
    }

    /// Photos of matches no longer on the lock screen
    private func removeUnusedPhotos() {
        var keep = Set<String>()
        for activity in Activity<LiveScoreAttributes>.activities { keep.insert(activity.attributes.matchId) }
        for activity in Activity<TeamScoreAttributes>.activities {
            keep.formUnion(TeamScorePhotoStore.keys(teamId: activity.attributes.teamId))
        }
        keep.formUnion(ownPhotosStored)
        LiveScorePhotoStore.removeAll(except: keep)
    }

    private func followed(_ target: LiveFollowTarget) -> Activity<LiveScoreAttributes>? {
        Activity<LiveScoreAttributes>.activities.first { activity in
            Self.target(of: activity) == target && activity.activityState == .active
        }
    }

    /// Hands every (new) push token to the server and forgets the match once
    /// the activity ends: the match finished (the server's "end"), or the user
    /// swiped it away on the lock screen
    private func observe<Attributes: ActivityAttributes>(_ activity: Activity<Attributes>, target: LiveFollowTarget,
                                                         removePhotos: @escaping @MainActor () -> Void) {
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
                    // Also tells the server to stop pushing to this token. Not
                    // `unfollow`: that ends the activity at once, and an ended
                    // match should keep its result on the lock screen
                    if LiveFollow.shared.isFollowing(target) { await LiveFollow.shared.ended(target) }
                    // An ended match keeps its result (with photos) on the lock screen; once it is gone the photos go too
                    if state == .dismissed { removePhotos() }
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
                // A finished own match keeps its result for its half hour
                if activity.activityState == .active && !activity.content.state.isFinished {
                    Task { await activity.end(nil, dismissalPolicy: .immediate) }
                }
                continue
            }
            guard let target = Self.target(of: activity), activity.activityState == .active else { continue }
            let state = activity.content.state
            LiveFollow.shared.restore(target, title: state.p1 + " – " + state.p2)
            observe(activity, target: target) { LiveScorePhotoStore.remove(matchId: target.id) }
        }
        for activity in Activity<TeamScoreAttributes>.activities where activity.activityState == .active {
            let target = Self.target(of: activity)
            let state = activity.content.state
            LiveFollow.shared.restore(target, title: state.home + " – " + state.away)
            observe(activity, target: target) { TeamScorePhotoStore.remove(teamId: target.id) }
        }
    }

    // MARK: - Followed team matches

    func startTeam(_ target: LiveFollowTarget, stand: TeamFollowStand) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw LiveFollowError.notAllowed }
        // No stale date: between two partijen nothing may change for a long time
        let content = ActivityContent(state: Self.teamContentState(stand), staleDate: nil)
        if let running = followedTeam(target) {
            await running.update(content)
            return
        }
        // As for a single match: the photos first, letters when that is slow
        removeUnusedPhotos()
        let photos = Task { await Self.downloadTeamPhotos(target) }
        let downloaded = await Self.finished(photos, within: 3)
        let attributes = TeamScoreAttributes(teamId: target.id, server: target.server)
        let activity: Activity<TeamScoreAttributes>
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: .token)
        } catch {
            TeamScorePhotoStore.remove(teamId: target.id)
            throw LiveFollowError.notAllowed
        }
        observe(activity, target: target) { TeamScorePhotoStore.remove(teamId: target.id) }
        if !downloaded {
            Task {
                _ = await photos.value
                await activity.update(activity.content)
            }
        }
    }

    private func followedTeam(_ target: LiveFollowTarget) -> Activity<TeamScoreAttributes>? {
        Activity<TeamScoreAttributes>.activities.first { activity in
            Self.target(of: activity) == target && activity.activityState == .active
        }
    }

    /// The partij photos of the followed team matches again (app start and
    /// back to the front): a partij that started since, or a photo added later,
    /// shows from then on. The activity is redrawn with its current stand.
    func refreshTeamPhotos() {
        for activity in Activity<TeamScoreAttributes>.activities where activity.activityState == .active {
            let target = Self.target(of: activity)
            Task {
                guard await Self.downloadTeamPhotos(target) else { return }
                await activity.update(activity.content)
            }
        }
    }

    /// Which partij photos the team page has (`photos` of GET /api/team/:id)
    private struct TeamPhotoFlags: Decodable {
        let photos: [String: [Bool]]?
    }

    /// GET /api/team/:id for the flags, then GET /api/team/:id/photo/<slot>/<1|2>
    /// per photo, stored as thumbnails for the widget (home = 1, away = 2).
    /// False when the team page could not be read (the stored photos stay).
    nonisolated static func downloadTeamPhotos(_ target: LiveFollowTarget) async -> Bool {
        guard let url = URL(string: target.server + "/api/team/" + target.id),
              let (body, response) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 10)),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let flags = try? JSONDecoder().decode(TeamPhotoFlags.self, from: body) else { return false }
        for slot in TeamScoreAttributes.ContentState.slots {
            let key = TeamScorePhotoStore.key(teamId: target.id, slot: slot)
            let sides = flags.photos?[String(slot)] ?? []
            for side in [1, 2] {
                guard side <= sides.count, sides[side - 1],
                      let photoURL = URL(string: target.server + "/api/team/" + target.id + "/photo/\(slot)/\(side)") else {
                    LiveScorePhotoStore.store(nil, matchId: key, player: side)
                    continue
                }
                var request = URLRequest(url: photoURL, timeoutInterval: 10)
                request.setValue("image/jpeg", forHTTPHeaderField: "Accept")
                if let (data, answer) = try? await URLSession.shared.data(for: request),
                   (answer as? HTTPURLResponse)?.statusCode == 200 {
                    LiveScorePhotoStore.store(data, matchId: key, player: side)
                }
            }
        }
        return true
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

    /// The players' photos of the own match (as stored in the app), once per
    /// match, before its first activity update
    func storeOwnPhotos(matchId: UUID, photos: [Data?]) {
        let id = matchId.uuidString
        guard !ownPhotosStored.contains(id) else { return }
        let enabled = UserDefaults.standard.object(forKey: LiveFollow.ownMatchKey) as? Bool ?? true
        guard enabled else { return }
        ownPhotosStored.insert(id)
        removeUnusedPhotos()
        for player in [1, 2] {
            LiveScorePhotoStore.store(player <= photos.count ? photos[player - 1] : nil, matchId: id, player: player)
        }
    }

    /// The scoring screen closed: a match under way leaves the lock screen
    /// (a finished one stays for its half hour)
    func endOwn(matchId: UUID) {
        let id = matchId.uuidString
        guard !ownFinished.contains(id) else { return }
        for activity in Activity<LiveScoreAttributes>.activities where activity.attributes.isOwnMatch && activity.attributes.matchId == id {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        ownPhotosStored.remove(id)
        LiveScorePhotoStore.remove(matchId: id)
    }

    // MARK: - Helpers

    static func target(of activity: Activity<LiveScoreAttributes>) -> LiveFollowTarget? {
        let attributes = activity.attributes
        guard !attributes.isOwnMatch else { return nil }
        return LiveFollowTarget(id: attributes.matchId, server: attributes.server)
    }

    static func target(of activity: Activity<TeamScoreAttributes>) -> LiveFollowTarget {
        LiveFollowTarget(id: activity.attributes.teamId, server: activity.attributes.server, kind: "team")
    }

    /// The server's team push, field by field (the extension has no Core)
    nonisolated static func teamContentState(_ stand: TeamFollowStand) -> TeamScoreAttributes.ContentState {
        let partijen = stand.partijen.map { partij in
            TeamScorePartij(slot: partij.slot, p1: partij.p1, p2: partij.p2, bestOf: partij.bestOf, gamesWon: partij.gamesWon,
                            score: partij.score, status: partij.status, winner: partij.winner, end: partij.end)
        }
        return TeamScoreAttributes.ContentState(home: stand.home, away: stand.away, partijen: partijen)
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
/// own match on the lock screen (playing, gameball, matchball, between, finished),
/// or a team match (team, team-finished)
enum LiveActivityDemo {
    @MainActor
    static func runIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-LiveActivityDemo") else { return }
        let name = index + 1 < arguments.count ? arguments[index + 1] : "playing"
        // One demo at a time on the lock screen
        for activity in Activity<TeamScoreAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        if name == "team" || name == "team-finished" {
            showTeamDemo(finished: name == "team-finished")
            return
        }
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

    /// A team match with E1 and E2 decided, E3 under way and E4 not started
    /// (`-LiveActivityDemo team`), or all four decided (`team-finished`)
    @MainActor
    private static func showTeamDemo(finished: Bool) {
        for activity in Activity<LiveScoreAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        var partijen = [
            TeamScorePartij(slot: 1, p1: "Gerard", p2: "Thé", bestOf: 5, gamesWon: [3, 0], score: [11, 4], status: "finished", winner: 1, end: nil),
            TeamScorePartij(slot: 2, p1: "Sanne", p2: "Mila", bestOf: 5, gamesWon: [1, 3], score: [8, 11], status: "finished", winner: 2, end: nil),
            TeamScorePartij(slot: 3, p1: "Paul", p2: "Joris", bestOf: 5, gamesWon: [1, 0], score: [7, 5], status: "playing", winner: nil, end: nil),
        ]
        if finished {
            partijen[2] = TeamScorePartij(slot: 3, p1: "Paul", p2: "Joris", bestOf: 5, gamesWon: [3, 1], score: [11, 6], status: "finished", winner: 1, end: nil)
            partijen.append(TeamScorePartij(slot: 4, p1: "Niels", p2: "Kees", bestOf: 5, gamesWon: [3, 2], score: [11, 9], status: "finished", winner: 1, end: nil))
        }
        let state = TeamScoreAttributes.ContentState(home: "Delft 7", away: "Ookmeer 2", partijen: partijen)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            _ = try? Activity.request(attributes: TeamScoreAttributes(teamId: "demo-team", server: "demo"),
                                      content: ActivityContent(state: state, staleDate: nil), pushType: nil)
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
