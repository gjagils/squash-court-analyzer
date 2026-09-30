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
import squash.analyzer.core.*

@RunWith(RobolectricTestRunner::class)
class RefereeMatchStoreTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val filename = "referee-resume-test.db"
    private lateinit var db: AppDatabase
    private lateinit var adapter: RoomRefereeMatchStore
    private fun open() {
        db = Room.databaseBuilder(context, AppDatabase::class.java, filename)
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6).build()
        adapter = RoomRefereeMatchStore(RefereeMatchStore(db.refereeMatchDao()), BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "test-install"))
    }
    @Before fun before() { context.deleteDatabase(filename); open() }
    @After fun after() { db.close(); context.deleteDatabase(filename) }

    private fun freshMatch(bestOf: Int = 5) =
        RefereeMatch(player1Name = "Hugo", player2Name = "Tegenstander", bestOf = bestOf, startingServer = Player.player1)

    @Test fun resumesScoresIdentityAndServiceAfterDatabaseReopen() = runTest {
        val match = freshMatch()
        match.player1Id = UUID()
        match.overrideSide(to = ServerSide.left)
        match.awardPoint(to = Player.player1)
        match.awardPoint(to = Player.player2)
        match.overrideSide(to = ServerSide.left)
        adapter.save(match)
        val stored = db.refereeMatchDao().matchById(match.id.uuidString)!!
        db.close(); open()
        val restored = adapter.loadInProgress()!!
        assertEquals(match.id, restored.id)
        assertEquals(match.player1Id, restored.player1Id)
        assertEquals("Hugo", restored.player1Name)
        assertEquals(1, restored.player1Score)
        assertEquals(1, restored.player2Score)
        assertEquals(Player.player2, restored.currentServer)
        assertEquals(ServerSide.left, restored.serverSide)
        assertEquals(ServerSide.left, restored.player1PreferredSide)
        assertEquals(ServerSide.left, restored.player2PreferredSide)
        assertEquals(2, restored.pointHistory.count)
        assertEquals(match.pointHistory.first().id, restored.pointHistory.first().id)
        // RefereeMatch.undo() pops a private, in-memory undo stack that is not
        // itself persisted; a restored match starts with an empty stack, so
        // undo only ever reaches back to points scored in the live session.
        assertFalse(restored.canUndo)
        assertEquals(stored.savedAt, db.refereeMatchDao().matchById(match.id.uuidString)!!.savedAt)
    }

    @Test fun undoBeforeSaveDoesNotPersistTheUndonePoint() = runTest {
        val match = freshMatch()
        match.awardPoint(to = Player.player1)
        match.awardPoint(to = Player.player2)
        match.undo()
        adapter.save(match)
        val restored = adapter.loadInProgress()!!
        assertEquals(1, restored.player1Score)
        assertEquals(0, restored.player2Score)
        assertEquals(1, restored.pointHistory.count)
        assertEquals(Player.player1, restored.currentServer)
    }

    @Test fun gameBoundaryIsResumedWithoutSkippingOrDuplicatingGames() = runTest {
        val match = freshMatch()
        repeat(11) { match.awardPoint(to = Player.player1) }
        adapter.save(match)
        var restored = adapter.loadInProgress()!!
        assertTrue(restored.isGameOver)
        assertEquals(0, restored.completedGames.count)
        restored.confirmNextGame()
        adapter.save(restored)
        restored = adapter.loadInProgress()!!
        assertEquals(1, restored.completedGames.count)
        assertEquals(2, restored.currentGameNumber)
        assertEquals(0, restored.player1Score)
        assertEquals(1, restored.player1GamesWon)
    }

    @Test fun completedAndAbandonedMatchesAreKeptButNeverOfferedForResume() = runTest {
        val completed = freshMatch(bestOf = 1)
        repeat(11) { completed.awardPoint(to = Player.player1) }
        adapter.save(completed)
        assertNull(adapter.loadInProgress())
        assertEquals(MatchStatus.COMPLETED, db.refereeMatchDao().matchById(completed.id.uuidString)!!.status)
        val unfinished = freshMatch()
        unfinished.awardPoint(to = Player.player1)
        adapter.save(unfinished)
        adapter.abandon(unfinished)
        assertNull(adapter.loadInProgress())
        assertEquals(MatchStatus.ABANDONED, db.refereeMatchDao().matchById(unfinished.id.uuidString)!!.status)
    }

    @Test fun versionThreeMigrationCreatesRefereeTables() = runTest {
        val match = freshMatch()
        match.awardPoint(to = Player.player1)
        adapter.save(match)
        db.close()
        SQLiteDatabase.openDatabase(context.getDatabasePath(filename).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("DROP TABLE referee_current_points")
            it.execSQL("DROP TABLE referee_points")
            it.execSQL("DROP TABLE referee_games")
            it.execSQL("DROP TABLE referee_matches")
            // badge_awards only exists from version 5 on; a real older database has none
            it.execSQL("DROP TABLE IF EXISTS badge_awards")
            it.version = 3
        }
        open()
        assertNull(adapter.loadInProgress())
        val fresh = freshMatch()
        adapter.save(fresh)
        assertEquals(fresh.id, adapter.loadInProgress()!!.id)
    }
}
