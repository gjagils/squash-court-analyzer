package com.squashanalyzer.android.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import skip.foundation.UUID
import skip.lib.Array as SwiftArray
import squash.analyzer.core.*

@RunWith(RobolectricTestRunner::class)
class CoachMatchStoreTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val filename = "coach-resume-test.db"
    private lateinit var db: AppDatabase
    private lateinit var adapter: RoomCoachMatchStore
    private fun open() {
        db = Room.databaseBuilder(context, AppDatabase::class.java, filename)
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6, AppDatabase.MIGRATION_6_7, AppDatabase.MIGRATION_7_8).build()
        adapter = RoomCoachMatchStore(MatchStore(db.matchDao()), BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "test-install"))
    }
    @Before fun before() { context.deleteDatabase(filename); open() }
    @After fun after() { db.close(); context.deleteDatabase(filename) }
    private fun point(game: Game, scorer: Player = Player.player1) {
        game.selectPlayer(scorer)
        game.selectPointType(PointType.winner)
        game.selectZone(CourtZone.frontLeft)
        game.addPoint(shotType = ShotType.drive)
    }

    @Test fun resumesScoresIdentityMetadataAndServiceAfterDatabaseReopen() = runTest {
        val match = Match()
        match.player1Name = "Hugo"
        match.player1Id = UUID()
        match.player1CoachingFocus = SwiftArray(listOf("Backhand"))
        match.player1CoachingNotes = "Lengte spelen"
        match.player1GamesBefore = 1
        match.currentGame.player1Name = "Hugo"
        match.currentGame.overrideSide(to = ServerSide.left)
        point(match.currentGame)
        point(match.currentGame, Player.player2)
        match.currentGame.overrideSide(to = ServerSide.left)
        adapter.save(match)
        val stored = db.matchDao().matchById(match.id.uuidString)!!
        db.close(); open()
        val restored = adapter.loadInProgress()!!
        assertEquals(match.id, restored.id)
        assertEquals(match.currentGame.id, restored.currentGame.id)
        assertEquals(match.player1Id, restored.player1Id)
        assertEquals("Lengte spelen", restored.player1CoachingNotes)
        assertEquals(listOf("Backhand"), restored.player1CoachingFocus.toList())
        assertEquals(2, restored.currentGameNumber)
        assertEquals(1, restored.currentGame.player1Score)
        assertEquals(1, restored.currentGame.player2Score)
        assertEquals(Player.player2, restored.currentGame.currentServer)
        assertEquals(ServerSide.left, restored.currentGame.serverSide)
        assertEquals(ServerSide.left, restored.currentGame.player1PreferredSide)
        assertEquals(ServerSide.left, restored.currentGame.player2PreferredSide)
        assertEquals(match.currentGame.points.first().id, restored.currentGame.points.first().id)
        assertEquals(ShotType.drive, restored.currentGame.points.first().shotType)
        restored.currentGame.undoLastPoint()
        adapter.save(restored)
        val again = adapter.loadInProgress()!!
        assertEquals(0, again.currentGame.player2Score)
        assertEquals(1, again.currentGame.points.count)
        assertEquals(Player.player1, again.currentGame.currentServer)
        assertEquals(stored.savedAt, db.matchDao().matchById(match.id.uuidString)!!.savedAt)
    }

    @Test fun gameBoundaryIsResumedWithoutSkippingOrDuplicatingGames() = runTest {
        val match = Match()
        repeat(11) { point(match.currentGame) }
        adapter.save(match)
        var restored = adapter.loadInProgress()!!
        assertTrue(restored.currentGame.isGameOver)
        assertEquals(1, restored.games.count)
        restored.onGameEnd()
        adapter.save(restored)
        restored = adapter.loadInProgress()!!
        assertEquals(2, restored.games.count)
        assertEquals(2, restored.currentGameNumber)
        assertEquals(0, restored.currentGame.player1Score)
        assertEquals(1, restored.player1GamesWon)
    }

    @Test fun completedAndAbandonedMatchesAreKeptButNeverOfferedForResume() = runTest {
        val completed = Match()
        repeat(3) { game ->
            repeat(11) { point(completed.currentGame) }
            if (game < 2) completed.onGameEnd()
        }
        adapter.save(completed)
        assertNull(adapter.loadInProgress())
        assertEquals(MatchStatus.COMPLETED, db.matchDao().matchById(completed.id.uuidString)!!.status)
        val unfinished = Match()
        point(unfinished.currentGame)
        adapter.save(unfinished)
        adapter.abandon(unfinished)
        assertNull(adapter.loadInProgress())
        assertEquals(MatchStatus.ABANDONED, db.matchDao().matchById(unfinished.id.uuidString)!!.status)
        assertEquals(3, db.matchDao().gamesForMatch(completed.id.uuidString).size)
    }

    @Test fun versionTwoMigrationKeepsPlayersAndMatchAndSupportsLegacyServiceFallback() = runTest {
        val match = Match()
        point(match.currentGame, Player.player2)
        adapter.save(match)
        db.playerDao().insert(PlayerEntity("hugo", "Hugo", "[]", "", 1.0))
        db.close()
        SQLiteDatabase.openDatabase(context.getDatabasePath(filename).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("ALTER TABLE games DROP COLUMN serviceState")
            // badge_awards only exists from version 5 on; a real older database has none
            it.execSQL("DROP TABLE IF EXISTS badge_awards")
            it.version = 2
        }
        open()
        assertEquals("Hugo", db.playerDao().byId("hugo")!!.name)
        val restored = adapter.loadInProgress()!!
        assertEquals(match.id, restored.id)
        assertEquals(1, restored.currentGame.player2Score)
        assertEquals(Player.player2, restored.currentGame.currentServer)
        adapter.save(restored)
        assertNotNull(db.matchDao().gamesForMatch(match.id.uuidString).first().serviceState)
    }
}
