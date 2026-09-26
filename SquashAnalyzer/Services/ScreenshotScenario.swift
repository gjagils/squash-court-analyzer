#if DEBUG
import Foundation
import SwiftData

/// Deterministic app states for App Store screenshots. Selected with the launch
/// argument `-screenshot <name>`; see scripts/screenshots.sh. Debug builds only,
/// so none of this ships in the App Store binary.
enum ScreenshotScenario: String, CaseIterable {
    case setup
    case coachMatch = "coach-match"
    case coachZone = "coach-zone"
    case coachGameOver = "coach-gameover"
    case referee
    case history
    case dashboard
    case badges

    /// The scenario requested at launch, if any
    static let current: ScreenshotScenario? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-screenshot"), i + 1 < args.count else { return nil }
        return ScreenshotScenario(rawValue: args[i + 1])
    }()

    static var isActive: Bool { current != nil }

    static let player1 = "Niels"
    static let player2 = "Paul"

    // MARK: - Coach

    /// Game 1 in progress, 4-3, with zones and shots so the last-point line shows
    static func makeCoachMatch() -> Match {
        let match = Match()
        match.setupMatch(player1: player1, player2: player2, startingServer: .player1)
        let game = match.currentGame
        game.setStartingServer(.player1)
        game.addPoint(to: .player1, pointType: .winner, at: .frontLeft, with: .drop)
        game.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil)
        game.addPoint(to: .player1, pointType: .winner, at: .backRight, with: .drive)
        game.addPoint(to: .player2, pointType: .winner, at: .frontRight, with: .boast)
        game.addPoint(to: .player1, pointType: .forcedError, at: .middleMiddle, with: .volley)
        game.addPoint(to: .player2, pointType: .winner, at: .backLeft, with: .lob)
        game.addPoint(to: .player1, pointType: .winner, at: .frontRight, with: .cross)
        return match
    }

    /// Same match, but player 1 has just been marked as scoring with a winner
    static func makeCoachZoneMatch() -> Match {
        let match = makeCoachMatch()
        match.currentGame.selectPlayer(.player1)
        match.currentGame.selectPointType(.winner)
        return match
    }

    /// Game 1 just won 11-3 by player 1, so the game-over overlay is showing
    static func makeCoachGameOverMatch() -> Match {
        let match = makeCoachMatch()
        let game = match.currentGame
        for _ in 0..<7 {
            game.addPoint(to: .player1, pointType: .winner, at: .frontLeft, with: .drop)
        }
        return match
    }

    /// A finished 3-1 match between two saved players in which both earned
    /// "5 op rij", stored with its awards so the badge strip and sheet show
    @MainActor
    static func makeCoachBadgesMatch(context: ModelContext) -> Match {
        func savedPlayer(_ name: String) -> SavedPlayer {
            if let existing = try? context.fetch(FetchDescriptor<SavedPlayer>(predicate: #Predicate { $0.name == name })).first {
                return existing
            }
            let player = SavedPlayer(name: name)
            context.insert(player)
            return player
        }
        let niels = savedPlayer(player1)
        let paul = savedPlayer(player2)
        let match = Match()
        match.setupMatch(player1: player1, player2: player2, startingServer: .player1,
                         player1Id: niels.id, player2Id: paul.id)
        let games: [(p1: Int, p2: Int, p2First: Bool)] = [(11, 6, false), (8, 11, true), (11, 9, false), (11, 4, false)]
        for (index, score) in games.enumerated() {
            let game = match.currentGame
            let first: Player = score.p2First ? .player2 : .player1
            let firstCount = score.p2First ? score.p2 - 1 : score.p1 - 1
            let otherCount = score.p2First ? score.p1 : score.p2
            for _ in 0..<firstCount { game.addPoint(to: first, pointType: .winner, at: .frontLeft, with: .drop) }
            for _ in 0..<otherCount { game.addPoint(to: first.opponent, pointType: .winner, at: .backRight, with: .drive) }
            game.addPoint(to: first, pointType: .winner, at: .frontLeft, with: .drop)
            if index < games.count - 1 { match.onGameEnd() }
        }
        match.status = .completed
        try? SwiftDataMatchRepository(context: context).upsert(match)
        return match
    }

    // MARK: - Referee

    /// Game 2 at 6-4 after an 11-9 first game, with a lively scoring line
    static func makeRefereeMatch() -> RefereeMatch {
        let match = RefereeMatch(player1Name: player1, player2Name: player2, bestOf: 5, startingServer: .player1)
        let game1: [Player] = [.player1, .player1, .player2, .player1, .player2, .player2, .player1, .player1,
                               .player2, .player1, .player2, .player2, .player1, .player1, .player2, .player2,
                               .player1, .player2, .player1, .player1]
        game1.forEach { match.awardPoint(to: $0) }          // 11-9
        match.confirmNextGame()
        let game2: [Player] = [.player2, .player1, .player1, .player2, .player1, .player2, .player1, .player2, .player1, .player1]
        for (i, p) in game2.enumerated() {
            if i == 6 { match.callStroke(to: p) } else { match.awardPoint(to: p) }
        }
        match.lastCallText = nil
        return match
    }

    // MARK: - Team import at launch: `-importTeam /host/path/team.zip` (simulator) or
    // `-importTeam team.zip` relative to the app's Documents folder (device via devicectl copy)

    @MainActor
    static func importTeamIfRequested(context: ModelContext) {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-importTeam"), i + 1 < args.count else { return }
        var path = args[i + 1]
        if !path.hasPrefix("/"),
           let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            path = documents.appendingPathComponent(path).path
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            print("[importTeam] no file at \(path)")
            return
        }
        do {
            let result = try TeamImportService.importTeam(zipData: data, context: context)
            print("[importTeam] \(result.summary)")
        } catch {
            print("[importTeam] failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Saved data

    /// Seeds the Niels–Paul sample match once, for the history and dashboard shots
    @MainActor
    static func seededSampleMatch(context: ModelContext) -> SavedMatch? {
        if let existing = try? context.fetch(FetchDescriptor<SavedMatch>()).first {
            return existing
        }
        SampleDataService.createSampleMatch(context: context)
        return try? context.fetch(FetchDescriptor<SavedMatch>()).first
    }
}
#endif
