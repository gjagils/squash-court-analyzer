import Foundation

/// Pulls what teammates put on the live page into every live team match on
/// this phone, without anyone opening the team match: the Competitie list,
/// the home screen and the app coming to the foreground call it. Until
/// 1 November 2026 only the team match screen read the page, so partijen of
/// teammates were missed when it was not opened before the page expired.
public enum TeamLiveSyncResult: Equatable, Sendable {
    case updated, unchanged
    /// The page is gone; the match is left as it is (its screen ends the live state)
    case gone
    case failed
}

@MainActor
public enum TeamLiveSync {
    /// Reads every live team match from the server and saves what changed;
    /// returns per match what happened. Never throws: a sync is best effort.
    public static func pull(store: any TeamMatchStore) async -> [UUID: TeamLiveSyncResult] {
        var results: [UUID: TeamLiveSyncResult] = [:]
        guard let matches = try? await store.loadAll() else { return results }
        for match in matches where match.isLive {
            guard let id = match.liveId else { continue }
            do {
                let state = try await TeamLive.shared.fetch(id: id)
                var changed = match
                if changed.mergeLive(state) {
                    try await store.save(changed)
                    results[match.id] = TeamLiveSyncResult.updated
                } else {
                    results[match.id] = TeamLiveSyncResult.unchanged
                }
            } catch let error as TeamLiveError {
                results[match.id] = error == TeamLiveError.gone ? TeamLiveSyncResult.gone : TeamLiveSyncResult.failed
            } catch {
                results[match.id] = TeamLiveSyncResult.failed
            }
        }
        // 4.0, T6: follow the live team matches with notifications, forget the rest
        let current = (try? await store.loadAll()) ?? matches
        await TeamAlertFollow.shared.sync(matches: current)
        return results
    }

    /// Whether anything on the phone changed
    public static func changed(_ results: [UUID: TeamLiveSyncResult]) -> Bool {
        for value in results.values where value == TeamLiveSyncResult.updated { return true }
        return false
    }
}
