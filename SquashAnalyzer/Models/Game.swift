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
    let id = UUID()

    // MARK: - Properties
    var player1Name: String = "Speler 1"
    var player2Name: String = "Speler 2"

    var player1Score: Int = 0
    var player2Score: Int = 0

    var currentServer: Player = .player1
    var startingServer: Player = .player1

    /// All points scored in this game (for analysis)
    var points: [Point] = []

    /// All lets called in this game
    var lets: [Let] = []

    /// Timestamp of game start or last point (for calculating rally duration)
    var lastPointTime: Date = Date()

    /// Currently selected player (for scoring flow - step 1)
    var selectedPlayer: Player? = nil

    /// Currently selected zone (for scoring flow - step 2)
    var selectedZone: CourtZone? = nil

    /// Track previous server for undo
    private var previousServers: [Player] = []

    /// Track previous point times for undo
    private var previousPointTimes: [Date] = []

    var isGameOver: Bool {
        let maxScore = max(player1Score, player2Score)
        let minScore = min(player1Score, player2Score)
        return maxScore >= 11 && (maxScore - minScore) >= 2
    }

    var winner: Player? {
        guard isGameOver else { return nil }
        return player1Score > player2Score ? .player1 : .player2
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
        } else if selectedZone == nil {
            return .selectZone
        } else {
            return .selectShot
        }
    }

    enum ScoringStep {
        case selectPlayer
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
        selectedZone = nil
    }

    /// Select a zone (step 2 of scoring)
    func selectZone(_ zone: CourtZone) {
        guard selectedPlayer != nil else { return }
        selectedZone = zone
    }

    /// Add a point with shot type (step 3 of scoring)
    func addPoint(shotType: ShotType) {
        guard let player = selectedPlayer, let zone = selectedZone else { return }
        addPoint(to: player, at: zone, with: shotType)
    }

    /// Clear the current selection
    func clearSelection() {
        selectedPlayer = nil
        selectedZone = nil
    }

    /// Go back one step in the scoring flow
    func goBackStep() {
        if selectedZone != nil {
            selectedZone = nil
        } else if selectedPlayer != nil {
            selectedPlayer = nil
        }
    }

    /// Add a point with all details
    func addPoint(to player: Player, at zone: CourtZone, with shotType: ShotType) {
        guard !isGameOver else { return }

        // Save current server and point time for undo
        previousServers.append(currentServer)
        previousPointTimes.append(lastPointTime)

        // Calculate rally duration (time since last point or game start)
        let now = Date()
        let duration = now.timeIntervalSince(lastPointTime)

        // Update score
        switch player {
        case .player1:
            player1Score += 1
        case .player2:
            player2Score += 1
        }

        // Record the point with duration
        let point = Point(
            scorer: player,
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

        // In squash, service changes when the receiver wins the rally
        if player != currentServer {
            currentServer = player
        }

        // Clear selection after scoring
        selectedPlayer = nil
        selectedZone = nil
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

        // Restore previous server
        if let previousServer = previousServers.popLast() {
            currentServer = previousServer
        }

        // Restore previous point time
        if let previousPointTime = previousPointTimes.popLast() {
            lastPointTime = previousPointTime
        }

        selectedPlayer = nil
        selectedZone = nil
    }

    func reset() {
        player1Score = 0
        player2Score = 0
        currentServer = startingServer
        points = []
        lets = []
        previousServers = []
        previousPointTimes = []
        lastPointTime = Date()
        selectedPlayer = nil
        selectedZone = nil
    }

    /// Record a let (replay of rally)
    func addLet(requestedBy player: Player) {
        let letCall = Let(
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
        selectedZone = nil
    }

    /// Undo the last let
    func undoLastLet() {
        _ = lets.popLast()
    }

    /// Get all lets requested by a player
    func letsRequested(by player: Player) -> [Let] {
        lets.filter { $0.requestedBy == player }
    }

    /// Total number of lets in this game
    var totalLets: Int {
        lets.count
    }

    func setStartingServer(_ player: Player) {
        startingServer = player
        currentServer = player
    }

    // MARK: - Analysis helpers

    /// Get all points won by a player
    func pointsWon(by player: Player) -> [Point] {
        points.filter { $0.scorer == player }
    }

    /// Get points won in a specific zone by a player
    func pointsWon(by player: Player, in zone: CourtZone) -> Int {
        points.filter { $0.scorer == player && $0.zone == zone }.count
    }

    /// Get points won with a specific shot type
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
        return zoneCounts.max(by: { $0.count < $1.count })?.zone
    }

    /// Get the best shot type for a player
    func bestShotType(for player: Player) -> ShotType? {
        let shotCounts = ShotType.allCases.map { shot in
            (shot: shot, count: pointsWon(by: player, with: shot))
        }
        return shotCounts.max(by: { $0.count < $1.count })?.shot
    }

    /// Get the worst zone for a player (most points lost)
    func worstZone(for player: Player) -> CourtZone? {
        let zoneCounts = CourtZone.allCases.map { zone in
            (zone: zone, count: pointsWon(by: player.opponent, in: zone))
        }
        return zoneCounts.max(by: { $0.count < $1.count })?.zone
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
