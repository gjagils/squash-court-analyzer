import Foundation
import Observation

/// Represents the current game state
@Observable
public class Game: Identifiable {
    public let id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }

    // MARK: - Properties
    public var player1Name: String = "Speler 1"
    public var player2Name: String = "Speler 2"

    public var player1Score: Int = 0
    public var player2Score: Int = 0

    public var currentServer: Player = .player1
    public var startingServer: Player = .player1

    /// Service box the current server serves from (same rules as RefereeMatch)
    public var serverSide: ServerSide = .right

    /// Box a player starts serving from after a hand-out or at the start of a game.
    /// Set by tapping Links/Rechts on the scoreboard; nil means the default right box.
    /// Match copies these into the next game so they hold for the whole match.
    public var player1PreferredSide: ServerSide? = nil
    public var player2PreferredSide: ServerSide? = nil

    /// All points scored in this game (for analysis)
    public var points: [Point] = []

    /// All lets called in this game
    public var lets: [LetCall] = []

    /// Timestamp of the Start tap or the last point (for calculating rally duration)
    public var lastPointTime: Date = Date()

    /// The clock for points and lets; tests set a fixed one to assert durations exactly
    public var now: () -> Date = { Date() }

    /// When play started: the coach's Start tap at the first serve, or the
    /// first point or let when Start was skipped. nil = warming up or the break
    /// before this game, which never counts as a rally.
    public var startedAt: Date? = nil

    /// `startedAt` came from the first point rather than the Start tap, so
    /// undoing that point goes back to before the start
    private var startedByFirstPoint = false

    /// Play has started in this game (Start tapped, or a point or let recorded)
    public var isStarted: Bool { startedAt != nil }

    /// Currently selected player (for scoring flow - step 1)
    public var selectedPlayer: Player? = nil

    /// Currently selected point type (for scoring flow - step 2)
    public var selectedPointType: PointType? = nil

    /// Currently selected zone (for scoring flow - step 3)
    public var selectedZone: CourtZone? = nil

    /// Kind of unforced error picked on the Down/Out/Service/Grond switch,
    /// handed in with the "Unforced error" tap
    private var pendingErrorKind: ErrorKind? = nil

    /// Track previous server for undo
    private var previousServers: [Player] = []

    /// Track previous service box for undo
    private var previousSides: [ServerSide] = []

    /// Track previous point times for undo
    private var previousPointTimes: [Date] = []

    public var isGameOver: Bool {
        ScoringEngine().isGameOver(SquashScore(player1: player1Score, player2: player2Score))
    }

    public var winner: Player? {
        ScoringEngine().winner(for: SquashScore(player1: player1Score, player2: player2Score))
    }

    public var canUndo: Bool {
        !points.isEmpty
    }

    public var lastPoint: Point? {
        points.last
    }

    /// Current step in scoring flow
    public var scoringStep: ScoringStep {
        if selectedPlayer == nil {
            return .selectPlayer
        } else if selectedPointType == nil {
            return .selectPointType
        } else if selectedPointType == PointType.unforcedError {
            return .selectErrorKind
        } else if let type = selectedPointType, needsZone(type), selectedZone == nil {
            return .selectZone
        } else {
            return .selectShot
        }
    }

    public enum ScoringStep {
        case selectPlayer
        case selectPointType
        /// After "Unforced error": Down, Out, Service or Grond (or not known)
        case selectErrorKind
        case selectZone
        case selectShot
    }

    // MARK: - Methods
    public func score(for player: Player) -> Int {
        switch player {
        case .player1: return player1Score
        case .player2: return player2Score
        }
    }

    public func name(for player: Player) -> String {
        switch player {
        case .player1: return player1Name
        case .player2: return player2Name
        }
    }

    /// Select a player (step 1 of scoring)
    public func selectPlayer(_ player: Player) {
        guard !isGameOver else { return }
        selectedPlayer = player
        selectedPointType = nil
        selectedZone = nil
    }

    /// Select a point type (step 2 of scoring). `errorKind` comes from the
    /// switch next to "Unforced error" and is only kept for that type.
    public func selectPointType(_ pointType: PointType, errorKind: ErrorKind? = nil) {
        guard let player = selectedPlayer else { return }
        guard !pointType.serverOnly || player == currentServer else { return }
        selectedPointType = pointType
        selectedZone = nil
        pendingErrorKind = pointType == PointType.unforcedError ? errorKind : nil

        // Unforced error: no zone or shot; the next step asks what kind of error
        // it was (`selectErrorKind`), unless the kind is already given.
        // Service point: the ball landed in the receiver's back quarter, opposite the
        // service box, so the zone is known without a tap.
        if pointType == PointType.unforcedError {
            if errorKind != nil { addPoint(shotType: nil) }
        } else if pointType == .servicePoint {
            selectedZone = Self.serviceLandingZone(from: serverSide)
            addPoint(shotType: nil)
        } else if !needsZone(pointType) {
            addPoint(shotType: nil)
        }
    }

    /// The kind of unforced error (nil = not known): scores the point
    public func selectErrorKind(_ kind: ErrorKind?) {
        guard selectedPlayer != nil, selectedPointType == PointType.unforcedError else { return }
        pendingErrorKind = kind
        addPoint(shotType: nil)
    }

    /// Whether this point type asks for a zone (an unforced error never does:
    /// where it went wrong matters less than how, see `ErrorKind`)
    public func needsZone(_ pointType: PointType) -> Bool {
        pointType.requiresZone
    }

    /// Kinds of unforced error that fit when `scorer` wins on the opponent's
    /// error: a service fault only when the opponent was serving
    public func errorKindOptions(whenScoring scorer: Player) -> [ErrorKind] {
        ErrorKind.options(errorByServer: currentServer != scorer)
    }

    // MARK: - Start of the game

    /// The coach taps Start at the first serve; from then the rally clock runs
    public func start(at date: Date = Date()) {
        guard startedAt == nil else { return }
        startedAt = date
        startedByFirstPoint = false
        lastPointTime = date
    }

    /// After a game is restored from the store: a game with points was under
    /// way, so going on with it needs no Start tap (the Start tap of a game
    /// without points is not stored)
    public func restoreStart() {
        guard startedAt == nil, let first = points.first else { return }
        startedAt = first.timestamp.addingTimeInterval(-first.duration)
        startedByFirstPoint = false
    }

    /// Take back a Start tap as long as no point has been played
    public func undoStart() {
        guard points.isEmpty else { return }
        startedAt = nil
        startedByFirstPoint = false
    }

    /// Seconds of the rally under way, 0 before the start
    public func rallySeconds(at date: Date = Date()) -> TimeInterval {
        guard startedAt != nil else { return 0.0 }
        return max(0.0, date.timeIntervalSince(lastPointTime))
    }

    /// Back quarter a serve from `side` lands in (cross-court from the box)
    public static func serviceLandingZone(from side: ServerSide) -> CourtZone {
        side == .right ? .backLeft : .backRight
    }

    /// Select a zone (step 3 of scoring; winner/forcedError/stroke, unforced error when wanted)
    public func selectZone(_ zone: CourtZone) {
        guard selectedPlayer != nil, let pointType = selectedPointType, needsZone(pointType) else { return }
        selectedZone = zone

        // A stroke has no winning shot — score as soon as the zone is known
        if !pointType.requiresShot {
            addPoint(shotType: nil)
        }
    }

    /// Add a point with shot type (step 4 of scoring)
    public func addPoint(shotType: ShotType?, isVolley: Bool = false) {
        guard let player = selectedPlayer, let pointType = selectedPointType else { return }
        let zone = selectedZone
        addPoint(to: player, pointType: pointType, at: zone, with: shotType, isVolley: isVolley,
                 errorKind: pendingErrorKind)
    }

    /// Clear the current selection
    public func clearSelection() {
        selectedPlayer = nil
        selectedPointType = nil
        selectedZone = nil
        pendingErrorKind = nil
    }

    /// Go back one step in the scoring flow
    public func goBackStep() {
        if selectedZone != nil {
            selectedZone = nil
        } else if selectedPointType != nil {
            selectedPointType = nil
        } else if selectedPlayer != nil {
            selectedPlayer = nil
        }
    }

    /// Add a point with all details
    public func addPoint(to player: Player, pointType: PointType, at zone: CourtZone?, with shotType: ShotType?, isVolley: Bool = false,
                         errorKind: ErrorKind? = nil) {
        guard !isGameOver else { return }

        // Save current server, service box and point time for undo
        previousServers.append(currentServer)
        previousSides.append(serverSide)
        previousPointTimes.append(lastPointTime)

        // Rally duration: since the last point or the Start tap. Without a Start
        // tap the first rally is not timed (it would hold the warm-up or the break).
        let now = self.now()
        var duration = 0.0
        if startedAt == nil {
            startedAt = now
            startedByFirstPoint = true
        } else {
            duration = max(0.0, now.timeIntervalSince(lastPointTime))
        }

        let nextScore = ScoringEngine().score(
            afterPointFor: player,
            from: SquashScore(player1: player1Score, player2: player2Score)
        )
        player1Score = nextScore.player1
        player2Score = nextScore.player2

        // Record the point with duration
        let point = Point(
            scorer: player,
            pointType: pointType,
            zone: zone,
            shotType: shotType,
            server: currentServer,
            player1Score: player1Score,
            player2Score: player2Score,
            timestamp: now,
            duration: duration,
            // Only a shot can be played out of the air, and never a lob
            isVolley: isVolley && (shotType?.allowsVolley ?? false),
            // Only an unforced error has a kind
            errorKind: pointType == PointType.unforcedError ? errorKind : nil
        )
        points.append(point)

        // Update last point time for next rally
        lastPointTime = now

        // Service rule: the server who wins a rally keeps serving from the other box.
        // On a hand-out the new server starts from their preferred box (right unless
        // Links/Rechts was tapped for that player earlier in the match).
        let next = ScoringEngine().service(afterRallyWonBy: player, from: ServiceState(server: currentServer, side: serverSide),
                                           handOutSide: handOutSide(for: player))
        currentServer = next.server
        serverSide = next.side

        // Clear selection after scoring
        selectedPlayer = nil
        selectedPointType = nil
        selectedZone = nil
        pendingErrorKind = nil
    }

    /// Undo the last point
    public func undoLastPoint() {
        guard let lastPoint = points.popLast() else { return }

        // Restore score
        switch lastPoint.scorer {
        case .player1:
            player1Score -= 1
        case .player2:
            player2Score -= 1
        }

        // Restore previous server and service box
        if let previousServer = previousServers.popLast(), let previousSide = previousSides.popLast() {
            currentServer = previousServer
            serverSide = previousSide
        } else {
            // Recovered game without undo history: derive the service state from the points
            restoreServiceState()
        }

        // Restore previous point time
        if let previousPointTime = previousPointTimes.popLast() {
            lastPointTime = previousPointTime
        }

        // The first point started the game (no Start tap): back to before the start
        if points.isEmpty && startedByFirstPoint {
            startedAt = nil
            startedByFirstPoint = false
        }

        selectedPlayer = nil
        selectedPointType = nil
        selectedZone = nil
    }

    /// Record a let (replay of rally)
    public func addLet(requestedBy player: Player) {
        guard !isGameOver else { return }
        let letCall = LetCall(
            requestedBy: player,
            server: currentServer,
            player1Score: player1Score,
            player2Score: player2Score,
            timestamp: now()
        )
        lets.append(letCall)

        // Reset the rally timer since the rally is replayed; a let also means play is under way
        lastPointTime = now()
        if startedAt == nil {
            startedAt = lastPointTime
            startedByFirstPoint = false
        }

        // Clear any selection in progress
        selectedPlayer = nil
        selectedPointType = nil
        selectedZone = nil
    }

    /// Get all lets requested by a player
    public func letsRequested(by player: Player) -> [LetCall] {
        lets.filter { $0.requestedBy == player }
    }

    /// Total number of lets in this game
    public var totalLets: Int {
        lets.count
    }

    /// Not `setStartingServer`: Kotlin auto-generates a JVM bean setter of that
    /// exact name for the `startingServer` property, and a method with the
    /// same name/signature is a hard "platform declaration clash" once
    /// transpiled.
    public func assignStartingServer(_ player: Player) {
        startingServer = player
        currentServer = player
        serverSide = handOutSide(for: player)
    }

    // MARK: - Service box

    public func preferredSide(for player: Player) -> ServerSide? {
        player == .player1 ? player1PreferredSide : player2PreferredSide
    }

    /// Box a player serves from when they take over service
    private func handOutSide(for player: Player) -> ServerSide {
        preferredSide(for: player) ?? .right
    }

    /// Correct the box the current server serves from and remember it as that
    /// player's hand-out box for the rest of the match. Alternation continues
    /// from the corrected box.
    public func overrideSide(to side: ServerSide) {
        guard !isGameOver, side != serverSide else { return }
        serverSide = side
        if currentServer == .player1 { player1PreferredSide = side } else { player2PreferredSide = side }
    }

    /// Bring the service state in line with the recorded points, e.g. after a
    /// game is restored from the store: the rallies are played again from the
    /// starting server, so a server who won rallies is in the right box (not
    /// back in their hand-out box).
    public func restoreServiceState() {
        var scorers: [Player] = []
        for point in points { scorers.append(point.scorer) }
        let state = ScoringEngine().service(replaying: scorers,
                                            from: ServiceState(server: startingServer, side: handOutSide(for: startingServer)),
                                            handOutSide: { player in self.handOutSide(for: player) })
        currentServer = state.server
        serverSide = state.side
    }

    // MARK: - Analysis helpers

    /// Get all points won by a player
    public func pointsWon(by player: Player) -> [Point] {
        points.filter { $0.scorer == player }
    }

    /// Get all winners by a player
    public func winners(by player: Player) -> [Point] {
        points.filter { $0.scorer == player && $0.pointType == .winner }
    }

    /// Get all forced errors by a player (opponent's error caused by player's pressure)
    public func forcedErrors(by player: Player) -> [Point] {
        points.filter { $0.scorer == player && $0.pointType == .forcedError }
    }

    /// Get all unforced errors by a player (errors not caused by player's shot)
    public func unforcedErrors(by player: Player) -> [Point] {
        points.filter { $0.scorer == player && $0.pointType == .unforcedError }
    }

    /// How often `player` made each kind of unforced error (the points the
    /// opponent won on them); errors without a kind are left out
    public func errorKindCounts(madeBy player: Player) -> [ErrorKind: Int] {
        var counts: [ErrorKind: Int] = [:]
        for point in unforcedErrors(by: player.opponent) {
            if let kind = point.errorKind { counts[kind] = (counts[kind] ?? 0) + 1 }
        }
        return counts
    }

    /// Points a player won with a volley: the switch, or an older "Volley" shot
    public func volleysWon(by player: Player) -> [Point] {
        points.filter { $0.scorer == player && ($0.isVolley || $0.shotType == ShotType.volley) }
    }

    /// The heatmap grid for this game: 3×3 as soon as a point lies in the
    /// middle column (played with 9 zones, or an older game), else 2×3
    public var heatmapLayout: CourtLayout {
        var zones: [CourtZone] = []
        for point in points {
            if let zone = point.zone { zones.append(zone) }
        }
        return CourtLayout.showing(zones)
    }

    /// Get all strokes awarded to a player
    public func strokes(by player: Player) -> [Point] {
        points.filter { $0.scorer == player && $0.pointType == .stroke }
    }

    /// Get all points a player won straight from the serve
    public func servicePoints(by player: Player) -> [Point] {
        points.filter { $0.scorer == player && $0.pointType == .servicePoint }
    }

    /// Get points won in a specific zone by a player (winners + forced errors only)
    public func pointsWon(by player: Player, in zone: CourtZone) -> Int {
        points.filter { $0.scorer == player && $0.zone == zone && $0.pointType != PointType.unforcedError }.count
    }

    /// Get points won with a specific shot type (winners + forced errors only)
    public func pointsWon(by player: Player, with shotType: ShotType) -> Int {
        points.filter { $0.scorer == player && $0.shotType == shotType }.count
    }

    /// Get all points lost by a player (won by opponent)
    public func pointsLost(by player: Player) -> [Point] {
        points.filter { $0.scorer == player.opponent }
    }

    /// Get total points played in a zone
    public func totalPoints(in zone: CourtZone) -> Int {
        points.filter { $0.zone == zone }.count
    }

    /// The zone where a player made the most winners and forced errors
    public func bestZone(for player: Player) -> CourtZone? {
        var best: CourtZone? = nil
        var most = 0
        for zone in CourtZone.allCases {
            var count = 0
            for point in attackingPoints(by: player) where point.zone == zone {
                count += 1
            }
            if count > most {
                most = count
                best = zone
            }
        }
        return best
    }

    /// Get the best shot type for a player
    public func bestShotType(for player: Player) -> ShotType? {
        let shotCounts = ShotType.allCases.map { shot in
            (shot: shot, count: pointsWon(by: player, with: shot))
        }
        guard let best = shotCounts.max(by: { $0.count < $1.count }), best.count > 0 else { return nil }
        return best.shot
    }

    /// Points a player made by playing: winners and forced errors. Strokes and
    /// service points say nothing about where the ball went, and the opponent's
    /// own errors are the opponent's.
    public func attackingPoints(by player: Player) -> [Point] {
        points.filter { $0.scorer == player && ($0.pointType == PointType.winner || $0.pointType == PointType.forcedError) }
    }

    // MARK: - Duration Analysis
    // Only timed rallies count: the first rally of a game entered without a
    // Start tap has no duration (see `Point.isTimed`).

    /// Rallies with a known duration
    public var timedPoints: [Point] {
        points.filter { $0.isTimed }
    }

    /// Average duration of points won by a player (in seconds)
    public func averageDurationWon(by player: Player) -> TimeInterval? {
        let wonPoints = timedPoints.filter { $0.scorer == player }
        guard !wonPoints.isEmpty else { return nil }
        let totalDuration = wonPoints.reduce(0.0) { $0 + $1.duration }
        return totalDuration / Double(wonPoints.count)
    }

    /// Average duration of points lost by a player (in seconds)
    public func averageDurationLost(by player: Player) -> TimeInterval? {
        let lostPoints = timedPoints.filter { $0.scorer == player.opponent }
        guard !lostPoints.isEmpty else { return nil }
        let totalDuration = lostPoints.reduce(0.0) { $0 + $1.duration }
        return totalDuration / Double(lostPoints.count)
    }

    /// Average duration of all points in the game
    public func averagePointDuration() -> TimeInterval? {
        let timed = timedPoints
        guard !timed.isEmpty else { return nil }
        let totalDuration = timed.reduce(0.0) { $0 + $1.duration }
        return totalDuration / Double(timed.count)
    }

    /// Longest point in the game
    public func longestPoint() -> Point? {
        timedPoints.max(by: { $0.duration < $1.duration })
    }

    /// Win percentage for short rallies (below median duration)
    public func shortRallyWinPercentage(for player: Player) -> Double? {
        let timed = timedPoints
        guard timed.count >= 2 else { return nil }
        let sortedDurations = timed.map { $0.duration }.sorted()
        let medianDuration = sortedDurations[sortedDurations.count / 2]

        let shortRallies = timed.filter { $0.duration < medianDuration }
        guard !shortRallies.isEmpty else { return nil }

        let won = shortRallies.filter { $0.scorer == player }.count
        return Double(won) / Double(shortRallies.count) * 100
    }

    /// Win percentage for long rallies (above median duration)
    public func longRallyWinPercentage(for player: Player) -> Double? {
        let timed = timedPoints
        guard timed.count >= 2 else { return nil }
        let sortedDurations = timed.map { $0.duration }.sorted()
        let medianDuration = sortedDurations[sortedDurations.count / 2]

        let longRallies = timed.filter { $0.duration >= medianDuration }
        guard !longRallies.isEmpty else { return nil }

        let won = longRallies.filter { $0.scorer == player }.count
        return Double(won) / Double(longRallies.count) * 100
    }

}
