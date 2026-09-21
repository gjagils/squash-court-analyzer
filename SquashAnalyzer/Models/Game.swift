import Foundation

/// Represents a player in the game
enum Player: String, CaseIterable, Identifiable, Codable {
    case player1 = "Speler 1"
    case player2 = "Speler 2"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .player1: return "S1"
        case .player2: return "S2"
        }
    }

    var opponent: Player {
        switch self {
        case .player1: return .player2
        case .player2: return .player1
        }
    }
}

/// Represents the current game state
@Observable
class Game: Identifiable {
    let id: UUID

    init(id: UUID = UUID()) {
        self.id = id
    }

    // MARK: - Properties
    var player1Name: String = "Speler 1"
    var player2Name: String = "Speler 2"

    var player1Score: Int = 0
    var player2Score: Int = 0

    var currentServer: Player = .player1
    var startingServer: Player = .player1

    /// Service box the current server serves from (same rules as RefereeMatch)
    var serverSide: ServerSide = .right

    /// Box a player starts serving from after a hand-out or at the start of a game.
    /// Set by tapping Links/Rechts on the scoreboard; nil means the default right box.
    /// Match copies these into the next game so they hold for the whole match.
    var player1PreferredSide: ServerSide? = nil
    var player2PreferredSide: ServerSide? = nil

    /// All points scored in this game (for analysis)
    var points: [Point] = []

    /// All lets called in this game
    var lets: [LetCall] = []

    /// Timestamp of game start or last point (for calculating rally duration)
    var lastPointTime: Date = Date()

    /// Currently selected player (for scoring flow - step 1)
    var selectedPlayer: Player? = nil

    /// Currently selected point type (for scoring flow - step 2)
    var selectedPointType: PointType? = nil

    /// Currently selected zone (for scoring flow - step 3)
    var selectedZone: CourtZone? = nil

    /// Track previous server for undo
    private var previousServers: [Player] = []

    /// Track previous service box for undo
    private var previousSides: [ServerSide] = []

    /// Track previous point times for undo
    private var previousPointTimes: [Date] = []

    var isGameOver: Bool {
        ScoringEngine().isGameOver(SquashScore(player1: player1Score, player2: player2Score))
    }

    var winner: Player? {
        ScoringEngine().winner(for: SquashScore(player1: player1Score, player2: player2Score))
    }

    var canUndo: Bool {
        !points.isEmpty
    }

    var lastPoint: Point? {
        points.last
    }

    /// Current step in scoring flow
    var scoringStep: ScoringStep {
        if selectedPlayer == nil {
            return .selectPlayer
        } else if selectedPointType == nil {
            return .selectPointType
        } else if selectedPointType?.requiresZone == true && selectedZone == nil {
            return .selectZone
        } else {
            return .selectShot
        }
    }

    enum ScoringStep {
        case selectPlayer
        case selectPointType
        case selectZone
        case selectShot
    }

    // MARK: - Methods
    func score(for player: Player) -> Int {
        switch player {
        case .player1: return player1Score
        case .player2: return player2Score
        }
    }

    func name(for player: Player) -> String {
        switch player {
        case .player1: return player1Name
        case .player2: return player2Name
        }
    }

    /// Select a player (step 1 of scoring)
    func selectPlayer(_ player: Player) {
        guard !isGameOver else { return }
        selectedPlayer = player
        selectedPointType = nil
        selectedZone = nil
    }

    /// Select a point type (step 2 of scoring)
    func selectPointType(_ pointType: PointType) {
        guard let player = selectedPlayer else { return }
        guard !pointType.serverOnly || player == currentServer else { return }
        selectedPointType = pointType
        selectedZone = nil

        // Unforced error: no zone or shot — score immediately.
        // Service point: the ball landed in the receiver's back quarter, opposite the
        // service box, so the zone is known without a tap.
        if pointType == .servicePoint {
            selectedZone = Self.serviceLandingZone(from: serverSide)
            addPoint(shotType: nil)
        } else if !pointType.requiresZone {
            addPoint(shotType: nil)
        }
    }

    /// Back quarter a serve from `side` lands in (cross-court from the box)
    static func serviceLandingZone(from side: ServerSide) -> CourtZone {
        side == .right ? .backLeft : .backRight
    }

    /// Select a zone (step 3 of scoring, only for winner/forcedError/stroke)
    func selectZone(_ zone: CourtZone) {
        guard selectedPlayer != nil, let pointType = selectedPointType, pointType.requiresZone else { return }
        selectedZone = zone

        // A stroke has no winning shot — score as soon as the zone is known
        if !pointType.requiresShot {
            addPoint(shotType: nil)
        }
    }

    /// Add a point with shot type (step 4 of scoring)
    func addPoint(shotType: ShotType?) {
        guard let player = selectedPlayer, let pointType = selectedPointType else { return }
        let zone = selectedZone
        addPoint(to: player, pointType: pointType, at: zone, with: shotType)
    }

    /// Clear the current selection
    func clearSelection() {
        selectedPlayer = nil
        selectedPointType = nil
        selectedZone = nil
    }

    /// Go back one step in the scoring flow
    func goBackStep() {
        if selectedZone != nil {
            selectedZone = nil
        } else if selectedPointType != nil {
            selectedPointType = nil
        } else if selectedPlayer != nil {
            selectedPlayer = nil
        }
    }

    /// Add a point with all details
    func addPoint(to player: Player, pointType: PointType, at zone: CourtZone?, with shotType: ShotType?) {
        guard !isGameOver else { return }

        // Save current server, service box and point time for undo
        previousServers.append(currentServer)
        previousSides.append(serverSide)
        previousPointTimes.append(lastPointTime)

        // Calculate rally duration (time since last point or game start)
        let now = Date()
        let duration = now.timeIntervalSince(lastPointTime)

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
            duration: duration
        )
        points.append(point)

        // Update last point time for next rally
        lastPointTime = now

        // Service rule: the server who wins a rally keeps serving from the other box.
        // On a hand-out the new server starts from their preferred box (right unless
        // Links/Rechts was tapped for that player earlier in the match).
        if player == currentServer {
            serverSide = serverSide.opposite
        } else {
            currentServer = player
            serverSide = handOutSide(for: player)
        }

        // Clear selection after scoring
        selectedPlayer = nil
        selectedPointType = nil
        selectedZone = nil
    }

    /// Quick entry scores a winner/forced error on the zone tap; the shot can be
    /// added afterwards until the next rally. Ignored once the point already has one.
    func assignShotToLastPoint(_ shot: ShotType) {
        guard let last = points.last, last.pointType.requiresShot, last.shotType == nil else { return }
        points[points.count - 1] = Point(
            id: last.id,
            scorer: last.scorer,
            pointType: last.pointType,
            zone: last.zone,
            shotType: shot,
            server: last.server,
            player1Score: last.player1Score,
            player2Score: last.player2Score,
            timestamp: last.timestamp,
            duration: last.duration
        )
    }

    /// True while the last point is still waiting for its (optional) shot: a
    /// winner/forced error without shot, with no let called since.
    var lastPointAwaitsShot: Bool {
        guard let last = points.last, last.pointType.requiresShot, last.shotType == nil else { return false }
        if let lastLet = lets.last, lastLet.timestamp > last.timestamp { return false }
        return true
    }

    /// Undo the last point
    func undoLastPoint() {
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

        selectedPlayer = nil
        selectedPointType = nil
        selectedZone = nil
    }

    func reset() {
        player1Score = 0
        player2Score = 0
        currentServer = startingServer
        serverSide = handOutSide(for: startingServer)
        points = []
        lets = []
        previousServers = []
        previousSides = []
        previousPointTimes = []
        lastPointTime = Date()
        selectedPlayer = nil
        selectedPointType = nil
        selectedZone = nil
    }

    /// Record a let (replay of rally)
    func addLet(requestedBy player: Player) {
        let letCall = LetCall(
            requestedBy: player,
            server: currentServer,
            player1Score: player1Score,
            player2Score: player2Score
        )
        lets.append(letCall)

        // Reset the rally timer since the rally is replayed
        lastPointTime = Date()

        // Clear any selection in progress
        selectedPlayer = nil
        selectedPointType = nil
        selectedZone = nil
    }

    /// Undo the last let
    func undoLastLet() {
        _ = lets.popLast()
    }

    /// Get all lets requested by a player
    func letsRequested(by player: Player) -> [LetCall] {
        lets.filter { $0.requestedBy == player }
    }

    /// Total number of lets in this game
    var totalLets: Int {
        lets.count
    }

    func setStartingServer(_ player: Player) {
        startingServer = player
        currentServer = player
        serverSide = handOutSide(for: player)
    }

    // MARK: - Service box

    func preferredSide(for player: Player) -> ServerSide? {
        player == .player1 ? player1PreferredSide : player2PreferredSide
    }

    /// Box a player serves from when they take over service
    private func handOutSide(for player: Player) -> ServerSide {
        preferredSide(for: player) ?? .right
    }

    /// Correct the box the current server serves from and remember it as that
    /// player's hand-out box for the rest of the match. Alternation continues
    /// from the corrected box.
    func overrideSide(to side: ServerSide) {
        guard !isGameOver, side != serverSide else { return }
        serverSide = side
        if currentServer == .player1 { player1PreferredSide = side } else { player2PreferredSide = side }
    }

    /// Bring the service state in line with the recorded points, e.g. after a
    /// game is restored from the store: the winner of the last rally serves next.
    func restoreServiceState() {
        currentServer = points.last?.scorer ?? startingServer
        serverSide = handOutSide(for: currentServer)
    }

    // MARK: - Analysis helpers

    /// Get all points won by a player
    func pointsWon(by player: Player) -> [Point] {
        points.filter { $0.scorer == player }
    }

    /// Get all winners by a player
    func winners(by player: Player) -> [Point] {
        points.filter { $0.scorer == player && $0.pointType == .winner }
    }

    /// Get all forced errors by a player (opponent's error caused by player's pressure)
    func forcedErrors(by player: Player) -> [Point] {
        points.filter { $0.scorer == player && $0.pointType == .forcedError }
    }

    /// Get all unforced errors by a player (errors not caused by player's shot)
    func unforcedErrors(by player: Player) -> [Point] {
        points.filter { $0.scorer == player && $0.pointType == .unforcedError }
    }

    /// Get all strokes awarded to a player
    func strokes(by player: Player) -> [Point] {
        points.filter { $0.scorer == player && $0.pointType == .stroke }
    }

    /// Get all points a player won straight from the serve
    func servicePoints(by player: Player) -> [Point] {
        points.filter { $0.scorer == player && $0.pointType == .servicePoint }
    }

    /// Get points won in a specific zone by a player (winners + forced errors only)
    func pointsWon(by player: Player, in zone: CourtZone) -> Int {
        points.filter { $0.scorer == player && $0.zone == zone }.count
    }

    /// Get points won with a specific shot type (winners + forced errors only)
    func pointsWon(by player: Player, with shotType: ShotType) -> Int {
        points.filter { $0.scorer == player && $0.shotType == shotType }.count
    }

    /// Get all points lost by a player (won by opponent)
    func pointsLost(by player: Player) -> [Point] {
        points.filter { $0.scorer == player.opponent }
    }

    /// Get win percentage for a player in a specific zone
    func winPercentage(for player: Player, in zone: CourtZone) -> Double {
        let won = points.filter { $0.scorer == player && $0.zone == zone }.count
        let lost = points.filter { $0.scorer == player.opponent && $0.zone == zone }.count
        let total = won + lost
        guard total > 0 else { return 0 }
        return Double(won) / Double(total) * 100
    }

    /// Get total points played in a zone
    func totalPoints(in zone: CourtZone) -> Int {
        points.filter { $0.zone == zone }.count
    }

    /// Get the best zone for a player (highest win count)
    func bestZone(for player: Player) -> CourtZone? {
        let zoneCounts = CourtZone.allCases.map { zone in
            (zone: zone, count: pointsWon(by: player, in: zone))
        }
        guard let best = zoneCounts.max(by: { $0.count < $1.count }), best.count > 0 else { return nil }
        return best.zone
    }

    /// Get the best shot type for a player
    func bestShotType(for player: Player) -> ShotType? {
        let shotCounts = ShotType.allCases.map { shot in
            (shot: shot, count: pointsWon(by: player, with: shot))
        }
        guard let best = shotCounts.max(by: { $0.count < $1.count }), best.count > 0 else { return nil }
        return best.shot
    }

    /// Get the worst zone for a player (most points lost)
    func worstZone(for player: Player) -> CourtZone? {
        let zoneCounts = CourtZone.allCases.map { zone in
            (zone: zone, count: pointsWon(by: player.opponent, in: zone))
        }
        guard let worst = zoneCounts.max(by: { $0.count < $1.count }), worst.count > 0 else { return nil }
        return worst.zone
    }

    /// Get recommendation: zones where opponent is weak
    func recommendedZones(against player: Player) -> [CourtZone] {
        let zoneCounts = CourtZone.allCases.map { zone in
            (zone: zone, lostCount: pointsWon(by: player.opponent, in: zone))
        }
        .filter { $0.lostCount > 0 }
        .sorted { $0.lostCount > $1.lostCount }

        return zoneCounts.prefix(3).map { $0.zone }
    }

    // MARK: - Duration Analysis

    /// Average duration of points won by a player (in seconds)
    func averageDurationWon(by player: Player) -> TimeInterval? {
        let wonPoints = pointsWon(by: player)
        guard !wonPoints.isEmpty else { return nil }
        let totalDuration = wonPoints.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(wonPoints.count)
    }

    /// Average duration of points lost by a player (in seconds)
    func averageDurationLost(by player: Player) -> TimeInterval? {
        let lostPoints = pointsLost(by: player)
        guard !lostPoints.isEmpty else { return nil }
        let totalDuration = lostPoints.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(lostPoints.count)
    }

    /// Average duration of all points in the game
    func averagePointDuration() -> TimeInterval? {
        guard !points.isEmpty else { return nil }
        let totalDuration = points.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(points.count)
    }

    /// Longest point in the game
    func longestPoint() -> Point? {
        points.max(by: { $0.duration < $1.duration })
    }

    /// Shortest point in the game
    func shortestPoint() -> Point? {
        points.min(by: { $0.duration < $1.duration })
    }

    /// Win percentage for short rallies (below median duration)
    func shortRallyWinPercentage(for player: Player) -> Double? {
        guard points.count >= 2 else { return nil }
        let sortedDurations = points.map { $0.duration }.sorted()
        let medianDuration = sortedDurations[sortedDurations.count / 2]

        let shortRallies = points.filter { $0.duration < medianDuration }
        guard !shortRallies.isEmpty else { return nil }

        let won = shortRallies.filter { $0.scorer == player }.count
        return Double(won) / Double(shortRallies.count) * 100
    }

    /// Win percentage for long rallies (above median duration)
    func longRallyWinPercentage(for player: Player) -> Double? {
        guard points.count >= 2 else { return nil }
        let sortedDurations = points.map { $0.duration }.sorted()
        let medianDuration = sortedDurations[sortedDurations.count / 2]

        let longRallies = points.filter { $0.duration >= medianDuration }
        guard !longRallies.isEmpty else { return nil }

        let won = longRallies.filter { $0.scorer == player }.count
        return Double(won) / Double(longRallies.count) * 100
    }

    /// Total game duration (sum of all rally durations)
    func totalGameDuration() -> TimeInterval {
        points.reduce(0) { $0 + $1.duration }
    }
}
