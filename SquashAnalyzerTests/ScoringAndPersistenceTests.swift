import XCTest
import SwiftData
@testable import SquashAnalyzer

final class ScoringAndPersistenceTests: XCTestCase {
    func testGameEndsAtElevenWithTwoPointLead() {
        let engine = ScoringEngine()
        XCTAssertTrue(engine.isGameOver(SquashScore(player1: 11, player2: 9)))
        XCTAssertFalse(engine.isGameOver(SquashScore(player1: 11, player2: 10)))
        XCTAssertTrue(engine.isGameOver(SquashScore(player1: 15, player2: 13)))
    }

    func testServiceChangesAndUndoRestoresIt() {
        let game = Game()
        game.setStartingServer(.player1)
        game.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.currentServer, .player2)
        XCTAssertEqual(game.player2Score, 1)

        game.undoLastPoint()
        XCTAssertEqual(game.currentServer, .player1)
        XCTAssertEqual(game.player2Score, 0)
    }

    func testServiceBoxAlternatesAndHandOutUsesPreferredBox() {
        let game = Game()
        game.setStartingServer(.player1)
        XCTAssertEqual(game.serverSide, .right)

        // The server who wins keeps serving from the other box
        game.addPoint(to: .player1, pointType: .winner, at: .frontLeft, with: .drop)
        XCTAssertEqual(game.currentServer, .player1)
        XCTAssertEqual(game.serverSide, .left)

        // Hand-out: the new server starts from the right box
        game.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.currentServer, .player2)
        XCTAssertEqual(game.serverSide, .right)

        // Tapping Links pins that box as player 2's hand-out box
        game.overrideSide(to: .left)
        XCTAssertEqual(game.serverSide, .left)
        XCTAssertEqual(game.preferredSide(for: .player2), .left)
        XCTAssertNil(game.preferredSide(for: .player1))

        game.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.serverSide, .right)
        game.addPoint(to: .player1, pointType: .unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.currentServer, .player1)
        XCTAssertEqual(game.serverSide, .right)
        game.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.currentServer, .player2)
        XCTAssertEqual(game.serverSide, .left)
    }

    func testUndoRestoresServiceBox() {
        let game = Game()
        game.setStartingServer(.player1)
        game.addPoint(to: .player1, pointType: .unforcedError, at: nil, with: nil)
        game.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.serverSide, .right)

        game.undoLastPoint()
        XCTAssertEqual(game.currentServer, .player1)
        XCTAssertEqual(game.serverSide, .left)

        game.undoLastPoint()
        XCTAssertEqual(game.currentServer, .player1)
        XCTAssertEqual(game.serverSide, .right)
    }

    func testPreferredBoxCarriesOverToNextGameAndWinnerServesFirst() {
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: .player1)
        let firstGame = match.currentGame
        firstGame.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil)
        firstGame.overrideSide(to: .left)
        for _ in 0..<10 { firstGame.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil) }
        XCTAssertEqual(firstGame.winner, .player2)

        match.onGameEnd()
        let secondGame = match.currentGame
        XCTAssertNotEqual(secondGame.id, firstGame.id)
        XCTAssertEqual(secondGame.currentServer, .player2)
        XCTAssertEqual(secondGame.serverSide, .left)
        XCTAssertEqual(secondGame.preferredSide(for: .player2), .left)
        XCTAssertNil(secondGame.preferredSide(for: .player1))
    }

    func testCoachShareTextUsesTheSharedLayouts() {
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: .player1)
        for _ in 0..<11 { match.currentGame.addPoint(to: .player1, pointType: .unforcedError, at: nil, with: nil) }

        // Between games: the finished game plus the stand, before "Volgende game" is tapped
        let betweenGames = match.whatsAppText
        XCTAssertTrue(betweenGames.contains("*Een* 1 – 0 Twee"), betweenGames)
        XCTAssertTrue(betweenGames.contains("11-0"), betweenGames)
        XCTAssertFalse(betweenGames.contains("🏆"), betweenGames)

        match.onGameEnd()
        for _ in 0..<11 { match.currentGame.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil) }
        let levelled = match.whatsAppText
        XCTAssertTrue(levelled.contains("Een 1 – 1 Twee"), levelled)
        XCTAssertTrue(levelled.contains("11-0 · 0-11"), levelled)

        match.onGameEnd()
        for _ in 0..<11 { match.currentGame.addPoint(to: .player1, pointType: .unforcedError, at: nil, with: nil) }
        match.onGameEnd()
        for _ in 0..<11 { match.currentGame.addPoint(to: .player1, pointType: .unforcedError, at: nil, with: nil) }
        XCTAssertTrue(match.isMatchOver)
        let final = match.whatsAppText
        XCTAssertTrue(final.contains("🏆 *Een* 3 – 1 Twee"), final)
        XCTAssertTrue(match.shareText(style: .report).contains("🏆 *Een wint met 3–1*"))
        XCTAssertTrue(match.shareText(style: .scorecard).contains("G4"))
        XCTAssertTrue(final.contains("11-0 · 0-11 · 11-0 · 11-0"), final)
    }

    func testHeadStartCountsTowardsTheStandAndGameNumbers() {
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: .player2, player1GamesBefore: 1, player2GamesBefore: 1)
        XCTAssertEqual(match.firstGameNumber, 3)
        XCTAssertEqual(match.currentGameNumber, 3)
        XCTAssertEqual(match.player1GamesWon, 1)
        XCTAssertEqual(match.player2GamesWon, 1)
        XCTAssertEqual(match.currentGame.currentServer, .player2)
        XCTAssertFalse(match.isMatchOver)

        for _ in 0..<11 { match.currentGame.addPoint(to: .player1, pointType: .unforcedError, at: nil, with: nil) }
        XCTAssertEqual(match.player1GamesWon, 2)
        XCTAssertTrue(match.whatsAppText.contains("vanaf game 3"), match.whatsAppText)
        XCTAssertTrue(match.whatsAppText.contains("*Een* 2 – 1 Twee"), match.whatsAppText)
        XCTAssertTrue(match.shareText(style: .scorecard).contains("G3"), match.shareText(style: .scorecard))

        match.onGameEnd()
        XCTAssertEqual(match.currentGameNumber, 4)
        for _ in 0..<11 { match.currentGame.addPoint(to: .player1, pointType: .unforcedError, at: nil, with: nil) }
        XCTAssertTrue(match.isMatchOver)
        XCTAssertEqual(match.matchWinner, .player1)
        XCTAssertEqual(match.games.count, 2, "only the tracked games exist")
    }

    func testHeadStartThatAlreadyDecidesTheMatchIsIgnored() {
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: .player1, player1GamesBefore: 3, player2GamesBefore: 0)
        XCTAssertEqual(match.player1GamesBefore, 0)
        XCTAssertEqual(match.firstGameNumber, 1)
        XCTAssertFalse(Match.isValidHeadStart(player1: 2, player2: 3))
        XCTAssertTrue(Match.isValidHeadStart(player1: 2, player2: 2))
    }

    func testStrokeScoresAfterZoneWithoutShot() {
        let game = Game()
        game.selectPlayer(.player2)
        game.selectPointType(.stroke)
        XCTAssertEqual(game.scoringStep, .selectZone)
        XCTAssertEqual(game.player2Score, 0, "a stroke still needs the zone")

        game.selectZone(.middleLeft)
        XCTAssertEqual(game.player2Score, 1)
        XCTAssertEqual(game.points.last?.pointType, .stroke)
        XCTAssertEqual(game.points.last?.zone, .middleLeft)
        XCTAssertNil(game.points.last?.shotType)
        XCTAssertNil(game.selectedPlayer, "selection is cleared after scoring")
        XCTAssertEqual(game.strokes(by: .player2).count, 1)
        XCTAssertEqual(game.pointsWon(by: .player2, in: .middleLeft), 1, "strokes count in the zone map")
    }

    func testServicePointScoresImmediatelyInTheReceiversBackQuarter() {
        let game = Game()
        game.setStartingServer(.player1)
        XCTAssertEqual(game.serverSide, .right)

        // Serve from the right box lands back left
        game.selectPlayer(.player1)
        game.selectPointType(.servicePoint)
        XCTAssertEqual(game.player1Score, 1)
        XCTAssertEqual(game.points.last?.pointType, .servicePoint)
        XCTAssertEqual(game.points.last?.zone, .backLeft)
        XCTAssertNil(game.points.last?.shotType)

        // Server keeps serving from the left box: lands back right
        XCTAssertEqual(game.serverSide, .left)
        game.selectPlayer(.player1)
        game.selectPointType(.servicePoint)
        XCTAssertEqual(game.points.last?.zone, .backRight)
        XCTAssertEqual(game.servicePoints(by: .player1).count, 2)

        // The receiver cannot score a service point
        game.selectPlayer(.player2)
        game.selectPointType(.servicePoint)
        XCTAssertEqual(game.player2Score, 0)
        XCTAssertEqual(game.scoringStep, .selectPointType)
    }

    func testLegacyStrokeAndAceShotsLoadAsPointTypes() {
        let saved = SavedPoint(pointNumber: 1, scorer: .player1, pointType: .winner, zone: .frontRight,
                               shotType: nil, server: .player1, player1Score: 1, player2Score: 0)
        saved.shotType = SavedPoint.legacyStrokeShot
        XCTAssertEqual(saved.savedPointType, .stroke)
        XCTAssertNil(saved.pointShotType)
        XCTAssertEqual(saved.pointZone, .frontRight)

        saved.shotType = SavedPoint.legacyAceShot
        XCTAssertEqual(saved.savedPointType, .servicePoint)
        XCTAssertNil(saved.pointShotType)
    }

    func testShotCanBeAddedToTheLastPointAfterwards() {
        let game = Game()
        game.addPoint(to: .player1, pointType: .winner, at: .frontLeft, with: nil)
        XCTAssertTrue(game.lastPointAwaitsShot)

        game.assignShotToLastPoint(.drop)
        XCTAssertEqual(game.points.last?.shotType, .drop)
        XCTAssertFalse(game.lastPointAwaitsShot)
        XCTAssertEqual(game.pointsWon(by: .player1, with: .drop), 1)

        // Only once, and never for points that take no shot
        game.assignShotToLastPoint(.drive)
        XCTAssertEqual(game.points.last?.shotType, .drop)
        game.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil)
        XCTAssertFalse(game.lastPointAwaitsShot)
        game.assignShotToLastPoint(.drive)
        XCTAssertNil(game.points.last?.shotType)

        // A let after the point closes the window
        game.addPoint(to: .player1, pointType: .forcedError, at: .backRight, with: nil)
        XCTAssertTrue(game.lastPointAwaitsShot)
        game.addLet(requestedBy: .player2)
        XCTAssertFalse(game.lastPointAwaitsShot)
    }

    func testUnforcedErrorCanRecordTheZoneWhenAsked() {
        let game = Game()
        game.zoneForUnforcedErrors = true
        game.selectPlayer(.player2)
        game.selectPointType(.unforcedError)
        XCTAssertEqual(game.player2Score, 0, "waits for the zone")
        XCTAssertEqual(game.scoringStep, .selectZone)

        game.selectZone(.frontLeft)
        XCTAssertEqual(game.player2Score, 1)
        XCTAssertEqual(game.points.last?.pointType, .unforcedError)
        XCTAssertEqual(game.points.last?.zone, .frontLeft)
        XCTAssertNil(game.points.last?.shotType)
        XCTAssertNil(game.selectedPlayer)

        // Default behaviour is unchanged
        let plain = Game()
        plain.selectPlayer(.player1)
        plain.selectPointType(.unforcedError)
        XCTAssertEqual(plain.player1Score, 1)
        XCTAssertNil(plain.points.last?.zone)
    }

    func testEmptyStatisticsHaveNoInventedBestResult() {
        let game = Game()
        XCTAssertNil(game.bestZone(for: .player1))
        XCTAssertNil(game.bestShotType(for: .player1))
        XCTAssertNil(game.worstZone(for: .player1))
    }

    func testUnforcedErrorScoresImmediately() {
        let game = Game()
        game.selectPlayer(.player1)
        game.selectPointType(.unforcedError)
        XCTAssertEqual(game.player1Score, 1)
        XCTAssertEqual(game.points.last?.pointType, .unforcedError)
        XCTAssertNil(game.points.last?.zone)
    }

    @MainActor
    func testRepositoryUpsertsOneMatchAndRestoresIt() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let schema = Schema(versionedSchema: SquashAnalyzerCurrentSchema.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SquashAnalyzerMigrationPlan.self,
            configurations: [config]
        )
        let repository = SwiftDataMatchRepository(context: container.mainContext)
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: .player1)
        match.currentGame.addPoint(to: .player1, pointType: .winner, at: .frontLeft, with: .drive)

        try repository.upsert(match)
        match.currentGame.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil)
        try repository.upsert(match)

        let saved = try container.mainContext.fetch(FetchDescriptor<SavedMatch>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.games.count, 1)
        XCTAssertEqual(saved.first?.games.first?.points.count, 2)
        XCTAssertEqual(try repository.mostRecentInProgressMatch()?.id, match.id)
    }

    @MainActor
    func testHeadStartSurvivesPersistenceAndRecovery() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let schema = Schema(versionedSchema: SquashAnalyzerCurrentSchema.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SquashAnalyzerMigrationPlan.self,
            configurations: [config]
        )
        let repository = SwiftDataMatchRepository(context: container.mainContext)
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: .player1, player1GamesBefore: 2, player2GamesBefore: 0)
        match.currentGame.addPoint(to: .player1, pointType: .unforcedError, at: nil, with: nil)
        try repository.upsert(match)

        let saved = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<SavedMatch>()).first)
        XCTAssertEqual(saved.player1GamesBefore, 2)
        XCTAssertEqual(saved.player1GamesWon, 2)
        XCTAssertEqual(saved.games.first?.gameNumber, 3)

        let restored = try XCTUnwrap(repository.mostRecentInProgressMatch())
        XCTAssertEqual(restored.player1GamesBefore, 2)
        XCTAssertEqual(restored.currentGameNumber, 3)
        XCTAssertEqual(restored.player1GamesWon, 2)

        // Backup round trip keeps it too
        let backup = try ExportService.exportFullBackup(players: [], matches: [saved], standaloneGames: [])
        container.mainContext.delete(saved)
        try container.mainContext.save()
        _ = try ExportService.importFullBackup(backup, context: container.mainContext)
        let imported = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<SavedMatch>()).first)
        XCTAssertEqual(imported.player1GamesBefore, 2)
    }

    func testCompletingResultFillsInOnlyTheMissedGameWinners() {
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: .player1)
        for winner in [Player.player1, .player2, .player1] {
            for _ in 0..<11 { match.currentGame.addPoint(to: winner, pointType: .unforcedError, at: nil, with: nil) }
            match.onGameEnd()
        }
        XCTAssertEqual(match.games.count, 4, "game 4 was started but not played")
        XCTAssertEqual(match.firstUnrecordedGameNumber, 4)

        XCTAssertFalse(match.isValidResultCompletion([.player2]), "2-2 does not decide the match")
        XCTAssertFalse(match.isValidResultCompletion([.player1, .player2]), "no games after the match is decided")
        XCTAssertTrue(match.isValidResultCompletion([.player2, .player1]))
        XCTAssertFalse(match.completeResult(with: [.player2]))
        XCTAssertFalse(match.isMatchOver)

        XCTAssertTrue(match.completeResult(with: [.player2, .player1]))
        XCTAssertEqual(match.games.count, 3, "the unplayed game 4 is dropped")
        XCTAssertEqual(match.player1GamesAfter, 1)
        XCTAssertEqual(match.player2GamesAfter, 1)
        XCTAssertEqual(match.player1GamesWon, 3)
        XCTAssertEqual(match.player2GamesWon, 2)
        XCTAssertEqual(match.matchWinner, .player1)
        XCTAssertEqual(match.status, .completed)
    }

    func testCompletingResultKeepsTheRalliesOfAnUnfinishedGame() {
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: .player1, player1GamesBefore: 1, player2GamesBefore: 1)
        for _ in 0..<5 { match.currentGame.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil) }
        XCTAssertEqual(match.firstUnrecordedGameNumber, 3)

        XCTAssertFalse(match.completeResult(with: [.player2]), "1-2 does not decide the match")
        XCTAssertTrue(match.completeResult(with: [.player2, .player2]))
        XCTAssertEqual(match.games.count, 1)
        XCTAssertEqual(match.games.first?.points.count, 5, "the rallies of game 3 stay for analysis")
        XCTAssertEqual(match.player2GamesWon, 3, "one before + two filled in")
        XCTAssertEqual(match.matchWinner, .player2)
    }

    @MainActor
    func testCompletedResultSurvivesPersistenceAndBackup() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let schema = Schema(versionedSchema: SquashAnalyzerCurrentSchema.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SquashAnalyzerMigrationPlan.self,
            configurations: [config]
        )
        let repository = SwiftDataMatchRepository(context: container.mainContext)
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: .player1)
        for _ in 0..<11 { match.currentGame.addPoint(to: .player1, pointType: .unforcedError, at: nil, with: nil) }
        match.onGameEnd()
        for _ in 0..<4 { match.currentGame.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil) }
        try repository.markAbandoned(match)

        let saved = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<SavedMatch>()).first)
        XCTAssertTrue(saved.isIncomplete)
        XCTAssertEqual(saved.matchStatus, .abandoned)
        XCTAssertEqual(saved.gameScoreChips, ["11-0", "0-4"])

        // Filled in later from the history
        let live = saved.toMatch()
        XCTAssertTrue(live.completeResult(with: [.player2, .player1, .player1]))
        try repository.upsert(live)

        XCTAssertFalse(saved.isIncomplete)
        XCTAssertEqual(saved.matchStatus, .completed)
        XCTAssertEqual(saved.player1GamesAfter, 2)
        XCTAssertEqual(saved.player2GamesAfter, 1)
        XCTAssertEqual(saved.winnerName, "Een")
        XCTAssertEqual(saved.gameScoreChips, ["11-0", "0-4", "–", "–"], "game 2 keeps its rallies, games 3-4 have no score")
        XCTAssertEqual(saved.games.first(where: { $0.gameNumber == 2 })?.points.count, 4)

        let backup = try ExportService.exportFullBackup(players: [], matches: [saved], standaloneGames: [])
        container.mainContext.delete(saved)
        try container.mainContext.save()
        _ = try ExportService.importFullBackup(backup, context: container.mainContext)
        let imported = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<SavedMatch>()).first)
        XCTAssertEqual(imported.player1GamesAfter, 2)
        XCTAssertEqual(imported.player2GamesAfter, 1)
        XCTAssertFalse(imported.isIncomplete)
    }

    @MainActor
    func testStoppedMatchCanBeDiscarded() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let schema = Schema(versionedSchema: SquashAnalyzerCurrentSchema.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SquashAnalyzerMigrationPlan.self,
            configurations: [config]
        )
        let repository = SwiftDataMatchRepository(context: container.mainContext)
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: .player1)
        match.currentGame.addPoint(to: .player1, pointType: .unforcedError, at: nil, with: nil)
        try repository.upsert(match)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<SavedMatch>()), 1)

        try repository.delete(match)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<SavedMatch>()), 0)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<SavedGame>()), 0)
    }

    @MainActor
    func testRestoredGameServesFromLastRallyWinner() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let schema = Schema(versionedSchema: SquashAnalyzerCurrentSchema.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: SquashAnalyzerMigrationPlan.self,
            configurations: [config]
        )
        let repository = SwiftDataMatchRepository(context: container.mainContext)
        let match = Match()
        match.setupMatch(player1: "Een", player2: "Twee", startingServer: .player1)
        match.currentGame.addPoint(to: .player1, pointType: .unforcedError, at: nil, with: nil)
        match.currentGame.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil)
        try repository.upsert(match)

        let restored = try XCTUnwrap(repository.mostRecentInProgressMatch())
        XCTAssertEqual(restored.currentGame.currentServer, .player2)
        XCTAssertEqual(restored.currentGame.serverSide, .right)

        // Undo without in-memory history derives the server from the remaining points
        restored.currentGame.undoLastPoint()
        XCTAssertEqual(restored.currentGame.currentServer, .player1)
    }

    @MainActor
    func testBackupRejectsInvalidChecksumBeforeImport() throws {
        let data = try ExportService.exportFullBackup(players: [], matches: [], standaloneGames: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(BackupEnvelope.self, from: data)
        let tampered = BackupEnvelope(
            formatVersion: envelope.formatVersion,
            schemaVersion: envelope.schemaVersion,
            appVersion: envelope.appVersion,
            createdAt: envelope.createdAt,
            checksum: "incorrect",
            payload: envelope.payload
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let tamperedData = try encoder.encode(tampered)

        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let schema = Schema(versionedSchema: SquashAnalyzerCurrentSchema.self)
        let container = try ModelContainer(for: schema, configurations: [config])
        XCTAssertThrowsError(try ExportService.importFullBackup(tamperedData, context: container.mainContext))
    }
}
