import XCTest
import SwiftData
@testable import SquashAnalyzer
import SquashAnalyzerCore

final class ScoringAndPersistenceTests: XCTestCase {
    func testGameEndsAtElevenWithTwoPointLead() {
        let engine = ScoringEngine()
        XCTAssertTrue(engine.isGameOver(SquashScore(player1: 11, player2: 9)))
        XCTAssertFalse(engine.isGameOver(SquashScore(player1: 11, player2: 10)))
        XCTAssertTrue(engine.isGameOver(SquashScore(player1: 15, player2: 13)))
    }

    func testServiceChangesAndUndoRestoresIt() {
        let game = Game()
        game.assignStartingServer(.player1)
        game.addPoint(to: .player2, pointType: .unforcedError, at: nil, with: nil)
        XCTAssertEqual(game.currentServer, .player2)
        XCTAssertEqual(game.player2Score, 1)

        game.undoLastPoint()
        XCTAssertEqual(game.currentServer, .player1)
        XCTAssertEqual(game.player2Score, 0)
    }

    func testServiceBoxAlternatesAndHandOutUsesPreferredBox() {
        let game = Game()
        game.assignStartingServer(.player1)
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
        game.assignStartingServer(.player1)
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
        game.assignStartingServer(.player1)
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

    func testUnforcedErrorKindSurvivesPersistence() {
        let game = Game()
        game.selectPlayer(.player2)
        game.selectPointType(.unforcedError, errorKind: .viaFloor)
        XCTAssertEqual(game.player2Score, 1, "no zone step for an unforced error")
        XCTAssertNil(game.points.last?.zone)

        let saved = SavedPoint.from(try! XCTUnwrap(game.points.last), pointNumber: 1)
        XCTAssertEqual(saved.errorKind, "Via de grond")
        XCTAssertEqual(saved.pointErrorKind, .viaFloor)
    }

    func testEmptyStatisticsHaveNoInventedBestResult() {
        let game = Game()
        XCTAssertNil(game.bestZone(for: .player1))
        XCTAssertNil(game.bestShotType(for: .player1))
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

    /// A backup file made by the Android app (2026-10-01, from the shared
    /// sample data) imports on iOS: one backup format for both platforms.
    @MainActor
    func testBackupMadeOnAndroidImports() throws {
        let data = try XCTUnwrap(Data(base64Encoded: Self.androidBackupBase64))
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let schema = Schema(versionedSchema: SquashAnalyzerCurrentSchema.self)
        let container = try ModelContainer(for: schema, configurations: [config])
        let counts = try ExportService.importFullBackup(data, context: container.mainContext)
        XCTAssertEqual(counts.players, 1)
        XCTAssertEqual(counts.matches, 2)
        let players = try container.mainContext.fetch(FetchDescriptor<SavedPlayer>())
        XCTAssertEqual(players.first?.name, "Paul Stéenks")
        let matches = try container.mainContext.fetch(FetchDescriptor<SavedMatch>())
        XCTAssertTrue(matches.contains { $0.player1CoachingNotes == "Let op \"lengte\" / tempo" })
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<SavedBadgeAward>()).count, 1)
    }

    private static let androidBackupBase64 = "ewogICJhcHBWZXJzaW9uIiA6ICJBbmRyb2lkIDAuMSIsCiAgImNoZWNrc3VtIiA6ICJhNDAyZjY2MmMzYWY4YzUwOTZhZTJkZTdhYjg0MmYwNzlkMzRmNmM3ZmMxNGE5NTU5YjAxZjkzNjMwMTVjZTdlIiwKICAiY3JlYXRlZEF0IiA6ICIyMDI2LTEwLTAxVDA3OjA1OjUyWiIsCiAgImZvcm1hdFZlcnNpb24iIDogMiwKICAicGF5bG9hZCIgOiB7CiAgICAiYmFja3VwRGF0ZSIgOiAiMjAyNi0xMC0wMVQwNzowNTo1MloiLAogICAgImJhZGdlQXdhcmRzIiA6IFsKICAgICAgewogICAgICAgICJhd2FyZGVkQnkiIDogImluc3RhbGwtQSIsCiAgICAgICAgImJhZGdlIiA6ICJmaXZlLWluLWEtcm93IiwKICAgICAgICAiY2FyZElkIiA6ICIwQTNDN0UxRC0yQjQ0LTRGMTAtOUMzQS01RDZFN0Y4MDkxQTIiLAogICAgICAgICJlYXJuZWRBdCIgOiAiMjAyNi0wOS0yMVQxNDoxMzoyMFoiLAogICAgICAgICJtYXRjaElkIiA6ICI2RjFDMkIzQS00RDVFLTRGNjAtOEE3Qi05QzBEMUUyRjNBNEIiLAogICAgICAgICJvcHBvbmVudE5hbWUiIDogIkphw69yIPCfjr4iCiAgICAgIH0KICAgIF0sCiAgICAibWF0Y2hlcyIgOiBbCiAgICAgIHsKICAgICAgICAiYmVzdE9mIiA6IDUsCiAgICAgICAgImdhbWVzIiA6IFsKICAgICAgICAgIHsKICAgICAgICAgICAgImdhbWVOdW1iZXIiIDogMSwKICAgICAgICAgICAgImlkIiA6ICJBQUFBQUFBQS1CQkJCLTRDQ0MtOERERC1FRUVFRUVFRUVFRUUiLAogICAgICAgICAgICAibGV0cyIgOiBbCiAgICAgICAgICAgICAgewogICAgICAgICAgICAgICAgImlkIiA6ICIyRTk4RTZDNS04Njg0LTRCNEQtOEM4RC02NjQ4N0ZGNDc5NTYiLAogICAgICAgICAgICAgICAgImxldE51bWJlciIgOiAxLAogICAgICAgICAgICAgICAgInBsYXllcjFTY29yZSIgOiAxLAogICAgICAgICAgICAgICAgInBsYXllcjJTY29yZSIgOiAxLAogICAgICAgICAgICAgICAgInJlcXVlc3RlZEJ5IiA6ICJTcGVsZXIgMiIsCiAgICAgICAgICAgICAgICAic2VydmVyIiA6ICJTcGVsZXIgMSIsCiAgICAgICAgICAgICAgICAidGltZXN0YW1wIiA6ICIyMDI2LTA5LTIxVDE0OjEzOjIwWiIKICAgICAgICAgICAgICB9CiAgICAgICAgICAgIF0sCiAgICAgICAgICAgICJwbGF5ZXIxTmFtZSIgOiAiUGF1bCBTdMOpZW5rcyIsCiAgICAgICAgICAgICJwbGF5ZXIxU2NvcmUiIDogMTEsCiAgICAgICAgICAgICJwbGF5ZXIyTmFtZSIgOiAiSmHDr3Ig8J+OviIsCiAgICAgICAgICAgICJwbGF5ZXIyU2NvcmUiIDogOSwKICAgICAgICAgICAgInBvaW50cyIgOiBbCiAgICAgICAgICAgICAgewogICAgICAgICAgICAgICAgImR1cmF0aW9uIiA6IDMuMjUsCiAgICAgICAgICAgICAgICAiaWQiIDogIjExMTExMTExLTIyMjItNDMzMy04NDQ0LTU1NTU1NTU1NTU1NSIsCiAgICAgICAgICAgICAgICAicGxheWVyMVNjb3JlIiA6IDEsCiAgICAgICAgICAgICAgICAicGxheWVyMlNjb3JlIiA6IDAsCiAgICAgICAgICAgICAgICAicG9pbnROdW1iZXIiIDogMSwKICAgICAgICAgICAgICAgICJwb2ludFR5cGUiIDogIldpbm5lciIsCiAgICAgICAgICAgICAgICAic2NvcmVyIiA6ICJTcGVsZXIgMSIsCiAgICAgICAgICAgICAgICAic2VydmVyIiA6ICJTcGVsZXIgMSIsCiAgICAgICAgICAgICAgICAic2hvdFR5cGUiIDogIkRyaXZlIiwKICAgICAgICAgICAgICAgICJ0aW1lc3RhbXAiIDogIjIwMjYtMDktMjFUMTQ6MTM6MjBaIiwKICAgICAgICAgICAgICAgICJ6b25lIiA6ICJWb29yIExpbmtzIgogICAgICAgICAgICAgIH0sCiAgICAgICAgICAgICAgewogICAgICAgICAgICAgICAgImR1cmF0aW9uIiA6IDEyLAogICAgICAgICAgICAgICAgImlkIiA6ICJCRDYxRjI4OS0xQUJFLTQ1QkEtOTNFMi01MTQ2NUNGMDg2NTciLAogICAgICAgICAgICAgICAgInBsYXllcjFTY29yZSIgOiAxLAogICAgICAgICAgICAgICAgInBsYXllcjJTY29yZSIgOiAxLAogICAgICAgICAgICAgICAgInBvaW50TnVtYmVyIiA6IDIsCiAgICAgICAgICAgICAgICAicG9pbnRUeXBlIiA6ICJVbmZvcmNlZCBFcnJvciIsCiAgICAgICAgICAgICAgICAic2NvcmVyIiA6ICJTcGVsZXIgMiIsCiAgICAgICAgICAgICAgICAic2VydmVyIiA6ICJTcGVsZXIgMSIsCiAgICAgICAgICAgICAgICAic2hvdFR5cGUiIDogIiIsCiAgICAgICAgICAgICAgICAidGltZXN0YW1wIiA6ICIyMDI2LTA5LTIxVDE0OjEzOjIwWiIsCiAgICAgICAgICAgICAgICAiem9uZSIgOiAiIgogICAgICAgICAgICAgIH0KICAgICAgICAgICAgXSwKICAgICAgICAgICAgInNhdmVkQXQiIDogIjIwMjYtMDktMjFUMTQ6MTM6MjBaIiwKICAgICAgICAgICAgInN0YXJ0aW5nU2VydmVyIiA6ICJTcGVsZXIgMSIsCiAgICAgICAgICAgICJ3aW5uZXIiIDogIlNwZWxlciAxIgogICAgICAgICAgfQogICAgICAgIF0sCiAgICAgICAgImlkIiA6ICI2RjFDMkIzQS00RDVFLTRGNjAtOEE3Qi05QzBEMUUyRjNBNEIiLAogICAgICAgICJtYXRjaFN0YXJ0aW5nU2VydmVyIiA6ICJTcGVsZXIgMSIsCiAgICAgICAgInBsYXllcjFDb2FjaGluZ0ZvY3VzIiA6IFsKICAgICAgICAgICJCYWNraGFuZCIsCiAgICAgICAgICAiRHJvcCIKICAgICAgICBdLAogICAgICAgICJwbGF5ZXIxQ29hY2hpbmdOb3RlcyIgOiAiTGV0IG9wIFwibGVuZ3RlXCIgXC8gdGVtcG8iLAogICAgICAgICJwbGF5ZXIxR2FtZXNBZnRlciIgOiAwLAogICAgICAgICJwbGF5ZXIxR2FtZXNCZWZvcmUiIDogMSwKICAgICAgICAicGxheWVyMUlkIiA6ICIwQTNDN0UxRC0yQjQ0LTRGMTAtOUMzQS01RDZFN0Y4MDkxQTIiLAogICAgICAgICJwbGF5ZXIxTmFtZSIgOiAiUGF1bCBTdMOpZW5rcyIsCiAgICAgICAgInBsYXllcjJDb2FjaGluZ0ZvY3VzIiA6IFsKCiAgICAgICAgXSwKICAgICAgICAicGxheWVyMkNvYWNoaW5nTm90ZXMiIDogIiIsCiAgICAgICAgInBsYXllcjJHYW1lc0FmdGVyIiA6IDAsCiAgICAgICAgInBsYXllcjJHYW1lc0JlZm9yZSIgOiAwLAogICAgICAgICJwbGF5ZXIyTmFtZSIgOiAiSmHDr3Ig8J+OviIsCiAgICAgICAgInNhdmVkQXQiIDogIjIwMjYtMDktMjFUMTQ6MTM6MjBaIiwKICAgICAgICAic3RhdHVzIiA6ICJjb21wbGV0ZWQiLAogICAgICAgICJ1cGRhdGVkQXQiIDogIjIwMjYtMDktMjFUMTQ6MTM6MjBaIgogICAgICB9LAogICAgICB7CiAgICAgICAgImJlc3RPZiIgOiA1LAogICAgICAgICJnYW1lcyIgOiBbCiAgICAgICAgICB7CiAgICAgICAgICAgICJnYW1lTnVtYmVyIiA6IDEsCiAgICAgICAgICAgICJpZCIgOiAiQkJCQkJCQkItQ0NDQy00RERELThFRUUtRkZGRkZGRkZGRkZGIiwKICAgICAgICAgICAgImxldHMiIDogWwoKICAgICAgICAgICAgXSwKICAgICAgICAgICAgInBsYXllcjFOYW1lIiA6ICJPdWQiLAogICAgICAgICAgICAicGxheWVyMVNjb3JlIiA6IDAsCiAgICAgICAgICAgICJwbGF5ZXIyTmFtZSIgOiAiU3BlbCIsCiAgICAgICAgICAgICJwbGF5ZXIyU2NvcmUiIDogMSwKICAgICAgICAgICAgInBvaW50cyIgOiBbCiAgICAgICAgICAgICAgewogICAgICAgICAgICAgICAgImR1cmF0aW9uIiA6IDQsCiAgICAgICAgICAgICAgICAiaWQiIDogIjFCMTAzMzg4LTYwRDQtNDY4My05QjY0LTIxQjRGMDMxQ0I2MyIsCiAgICAgICAgICAgICAgICAicGxheWVyMVNjb3JlIiA6IDAsCiAgICAgICAgICAgICAgICAicGxheWVyMlNjb3JlIiA6IDEsCiAgICAgICAgICAgICAgICAicG9pbnROdW1iZXIiIDogMSwKICAgICAgICAgICAgICAgICJwb2ludFR5cGUiIDogIlNlcnZpY2UgUG9pbnQiLAogICAgICAgICAgICAgICAgInNjb3JlciIgOiAiU3BlbGVyIDIiLAogICAgICAgICAgICAgICAgInNlcnZlciIgOiAiU3BlbGVyIDIiLAogICAgICAgICAgICAgICAgInNob3RUeXBlIiA6ICIiLAogICAgICAgICAgICAgICAgInRpbWVzdGFtcCIgOiAiMjAyNi0wOS0yMVQxNDoxMzoyMFoiLAogICAgICAgICAgICAgICAgInpvbmUiIDogIkFjaHRlciBMaW5rcyIKICAgICAgICAgICAgICB9CiAgICAgICAgICAgIF0sCiAgICAgICAgICAgICJzYXZlZEF0IiA6ICIyMDI2LTA5LTIxVDE0OjEzOjIwWiIsCiAgICAgICAgICAgICJzdGFydGluZ1NlcnZlciIgOiAiU3BlbGVyIDIiCiAgICAgICAgICB9CiAgICAgICAgXSwKICAgICAgICAiaWQiIDogIkJCQkJCQkJCLUNDQ0MtNERERC04RUVFLUZGRkZGRkZGRkZGRiIsCiAgICAgICAgIm1hdGNoU3RhcnRpbmdTZXJ2ZXIiIDogIlNwZWxlciAyIiwKICAgICAgICAicGxheWVyMUNvYWNoaW5nRm9jdXMiIDogWwoKICAgICAgICBdLAogICAgICAgICJwbGF5ZXIxQ29hY2hpbmdOb3RlcyIgOiAiIiwKICAgICAgICAicGxheWVyMUdhbWVzQWZ0ZXIiIDogMCwKICAgICAgICAicGxheWVyMUdhbWVzQmVmb3JlIiA6IDAsCiAgICAgICAgInBsYXllcjFOYW1lIiA6ICJPdWQiLAogICAgICAgICJwbGF5ZXIyQ29hY2hpbmdGb2N1cyIgOiBbCgogICAgICAgIF0sCiAgICAgICAgInBsYXllcjJDb2FjaGluZ05vdGVzIiA6ICIiLAogICAgICAgICJwbGF5ZXIyR2FtZXNBZnRlciIgOiAwLAogICAgICAgICJwbGF5ZXIyR2FtZXNCZWZvcmUiIDogMCwKICAgICAgICAicGxheWVyMk5hbWUiIDogIlNwZWwiLAogICAgICAgICJzYXZlZEF0IiA6ICIyMDI2LTA5LTIxVDE0OjEzOjIwWiIsCiAgICAgICAgInN0YXR1cyIgOiAiY29tcGxldGVkIiwKICAgICAgICAidXBkYXRlZEF0IiA6ICIyMDI2LTA5LTIxVDE0OjEzOjIwWiIKICAgICAgfQogICAgXSwKICAgICJwbGF5ZXJzIiA6IFsKICAgICAgewogICAgICAgICJjb2FjaGluZ0ZvY3VzQXJlYXMiIDogWwogICAgICAgICAgIkRyb3AiCiAgICAgICAgXSwKICAgICAgICAiY29hY2hpbmdOb3RlcyIgOiAiIiwKICAgICAgICAiY3JlYXRlZEF0IiA6ICIyMDI2LTA5LTIxVDE0OjEzOjIwWiIsCiAgICAgICAgImlkIiA6ICIwQTNDN0UxRC0yQjQ0LTRGMTAtOUMzQS01RDZFN0Y4MDkxQTIiLAogICAgICAgICJuYW1lIiA6ICJQYXVsIFN0w6llbmtzIgogICAgICB9CiAgICBdLAogICAgInN0YW5kYWxvbmVHYW1lcyIgOiBbCgogICAgXSwKICAgICJ2ZXJzaW9uIiA6IDIKICB9LAogICJzY2hlbWFWZXJzaW9uIiA6ICIxLjAuMCIKfQ=="
}
