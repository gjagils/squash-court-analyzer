package com.squashanalyzer.android.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import skip.lib.Array as SwiftArray
import squash.analyzer.core.PlayerProfile

@RunWith(RobolectricTestRunner::class)
class PlayerStoreTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val databaseName = "player-store-test.db"
    private lateinit var db: AppDatabase
    private lateinit var store: RoomPlayerStore

    private fun open() {
        db = Room.databaseBuilder(context, AppDatabase::class.java, databaseName)
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6, AppDatabase.MIGRATION_6_7, AppDatabase.MIGRATION_7_8, AppDatabase.MIGRATION_8_9).build()
        store = RoomPlayerStore(db.playerDao())
    }

    @Before fun setUp() { context.deleteDatabase(databaseName); open() }
    @After fun tearDown() { db.close(); context.deleteDatabase(databaseName) }

    @Test fun profilesSurviveCloseAndReopenWithStableIdentity() = runTest {
        store.savePlayer(PlayerProfile(id = "hugo", name = "  Hugo \n", coachingFocusAreas = SwiftArray(listOf("Backhand", "Tactiek")), coachingNotes = "Rustig op de T\nTweede regel", createdAt = 123.0))
        db.close()
        open()
        val saved = store.loadPlayers().first()
        assertEquals("hugo", saved.id)
        assertEquals("Hugo", saved.name)
        assertEquals("Rustig op de T\nTweede regel", saved.coachingNotes)
        assertEquals(listOf("Backhand", "Tactiek"), saved.coachingFocusAreas.toList())
        assertEquals(123.0, saved.createdAt, 0.0)
    }

    @Test fun editingPreservesCreationDatePhotoAndCardMetadata() = runTest {
        db.playerDao().insert(PlayerEntity("one", "Voor", "[]", "", 12.0, byteArrayOf(1, 2), "shared-card"))
        store.savePlayer(PlayerProfile(id = "one", name = "Na", coachingFocusAreas = SwiftArray(listOf("Drop")), coachingNotes = "Nieuwe notitie", createdAt = 999.0))
        val row = db.playerDao().byId("one")!!
        assertEquals(1, db.playerDao().all().size)
        assertEquals("Na", row.name)
        assertEquals("Nieuwe notitie", row.coachingNotes)
        assertEquals(12.0, row.createdAt, 0.0)
        assertArrayEquals(byteArrayOf(1, 2), row.photoData)
        assertEquals("shared-card", row.cardId)
    }

    @Test fun duplicateNamesRemainIndependentAndDirectoryIsSorted() = runTest {
        store.savePlayer(PlayerProfile(id = "a", name = "Zoe"))
        store.savePlayer(PlayerProfile(id = "b", name = "Anna"))
        store.savePlayer(PlayerProfile(id = "c", name = "Anna"))
        assertEquals(listOf("b", "c", "a"), store.loadPlayers().map { it.id }.toList())
        store.deletePlayer("b")
        assertEquals(listOf("c", "a"), store.loadPlayers().map { it.id }.toList())
    }

    @Test fun blankNameIsRejectedWithoutOverwritingExistingPlayer() = runTest {
        store.savePlayer(PlayerProfile(id = "a", name = "Hugo"))
        try {
            store.savePlayer(PlayerProfile(id = "a", name = " \n\t"))
            fail("Blank names must fail")
        } catch (_: IllegalArgumentException) { }
        assertEquals("Hugo", store.loadPlayers().first().name)
    }

    @Test fun migrationPreservesMatchesAndDeletingPlayerKeepsHistory() = runTest {
        val match = MatchRecord(id = "match", player1Name = "Hugo", player2Name = "Bas", player1Id = "hugo",
            matchStartingServer = "player1", bestOf = 5, savedAt = 100L, updatedAt = 100L, status = MatchStatus.IN_PROGRESS)
        MatchStore(db.matchDao()).upsert(match)
        db.close()
        // Reconstruct the exact v1 shape: the four match tables are unchanged
        // in v2. Remove only the new player table and set SQLite's user_version.
        SQLiteDatabase.openDatabase(context.getDatabasePath(databaseName).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("DROP TABLE players")
            it.execSQL("ALTER TABLE games DROP COLUMN serviceState")
            // badge_awards only exists from version 5 on; a real older database has none
            it.execSQL("DROP TABLE IF EXISTS badge_awards")
            it.version = 1
        }
        open() // Room now performs MIGRATION_1_2 and validates its result.
        assertEquals(match.id, MatchStore(db.matchDao()).mostRecentInProgressMatch()?.id)
        store.savePlayer(PlayerProfile(id = "hugo", name = "Hugo"))
        store.deletePlayer("hugo")
        assertTrue(store.loadPlayers().isEmpty)
        val retained = MatchStore(db.matchDao()).mostRecentInProgressMatch()!!
        assertEquals(match.id, retained.id)
        assertEquals("Hugo", retained.player1Name)
        assertEquals("hugo", retained.player1Id)
    }
}
