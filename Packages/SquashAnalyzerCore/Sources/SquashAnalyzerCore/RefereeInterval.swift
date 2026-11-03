import Foundation

// MARK: - Officiële timers (3.2, R2)

/// The timed intervals a referee keeps, from the World Squash Rules of Singles
/// Squash 2025 (squash.nl, 1 September 2025): rule 4.1 a warm-up of at most 4
/// minutes with a change of sides after 2 ("Half-time"), rule 7.1 at most 1
/// minute from the end of the warm-up to the start of play and 2 minutes
/// between games, and the calls "15 seconds" and "Time" (rule 3.6.7).
public enum RefereeIntervalKind: String, Equatable, Sendable {
    case warmup
    case toStart
    case betweenGames

    /// The length in seconds
    public var length: Int {
        switch self {
        case .warmup: return 240
        case .toStart: return 60
        case .betweenGames: return 120
        }
    }
}

/// What the referee announces during an interval
public enum RefereeCall: String, Equatable, Sendable {
    /// 2 minutes of the warm-up have passed: the players change sides
    case halfTime
    /// 15 seconds of the interval remain
    case fifteenSeconds
    /// The interval is over
    case time
}

/// One running interval: what it is and when it began
public struct RefereeInterval: Equatable, Sendable {
    public let kind: RefereeIntervalKind
    public let startedAt: Date

    public init(kind: RefereeIntervalKind, startedAt: Date) {
        self.kind = kind
        self.startedAt = startedAt
    }

    /// Whole seconds left at `date`; 0 when the time is up (never negative)
    public func remaining(at date: Date) -> Int {
        let passed = Int(date.timeIntervalSince(startedAt))
        return max(0, kind.length - max(0, passed))
    }

    /// The last call that is due at `date`, nil before the first one
    public func call(at date: Date) -> RefereeCall? {
        let left = remaining(at: date)
        if left == 0 { return RefereeCall.time }
        if left <= 15 { return RefereeCall.fifteenSeconds }
        if kind == RefereeIntervalKind.warmup && left <= kind.length / 2 { return RefereeCall.halfTime }
        return nil
    }

    /// "3:05", "0:15"
    public static func clockText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let rest = seconds % 60
        return "\(minutes):" + (rest < 10 ? "0" : "") + "\(rest)"
    }
}

extension RefereeMatch {
    /// No rally played yet in this match (the warm-up may run)
    public var isBeforeFirstRally: Bool {
        completedGames.isEmpty && pointHistory.isEmpty && currentGameNumber == firstGameNumber
    }

    /// The interval running now, if any: the warm-up (after "Start inspelen")
    /// and the minute to the start of play that follows it, or the break after
    /// a game until its first rally. The first rally ends any interval.
    public func runningInterval(at date: Date) -> RefereeInterval? {
        if isMatchOver || !pointHistory.isEmpty { return nil }
        if isBeforeFirstRally {
            guard let warmup = warmupStartedAt else { return nil }
            let warmupEnd = warmup.addingTimeInterval(Double(RefereeIntervalKind.warmup.length))
            if date < warmupEnd { return RefereeInterval(kind: RefereeIntervalKind.warmup, startedAt: warmup) }
            return RefereeInterval(kind: RefereeIntervalKind.toStart, startedAt: warmupEnd)
        }
        guard let start = intervalStartedAt else { return nil }
        return RefereeInterval(kind: RefereeIntervalKind.betweenGames, startedAt: start)
    }
}
