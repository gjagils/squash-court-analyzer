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
    case referee
    case history
    case dashboard

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

    // MARK: - Team import from a host path (simulator only), e.g. `-importTeam /path/team.zip`

    @MainActor
    static func importTeamIfRequested(context: ModelContext) {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-importTeam"), i + 1 < args.count,
              let data = FileManager.default.contents(atPath: args[i + 1]) else { return }
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
