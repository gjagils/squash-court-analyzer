package com.squashanalyzer.android.data

import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Proves the Room-backed MatchStore behaves like SwiftDataMatchRepository
 * (SquashAnalyzerTests/ScoringAndPersistenceTests.swift covers the iOS side
 * of the same four operations): upsert/read round-trips a match with its
 * games, points and lets; markAbandoned flips status; delete removes
 * everything including children (foreign-key cascade). Runs on the local
 * JVM via Robolectric — no emulator needed, same idea as `swift test` for
 * the shared package.
 */
@RunWith(RobolectricTestRunner::class)
class MatchStoreTest {
    private lateinit var db: AppDatabase
    private lateinit var store: MatchStore

    @Before
    fun setUp() {
        db = Room.inMemoryDatabaseBuilder(ApplicationProvider.getApplicationContext(), AppDatabase::class.java)
            .allowMainThreadQueries()
            .addCallback(object : RoomDatabase.Callback() {
                override fun onOpen(db: SupportSQLiteDatabase) {
                    super.onOpen(db)
                    db.execSQL("PRAGMA foreign_keys=ON")
                }
            })
            .build()
        store = MatchStore(db.matchDao())
    }

    @After
    fun tearDown() {
        db.close()
    }

    private fun sampleMatch(id: String = newId(), status: String = MatchStatus.IN_PROGRESS): MatchRecord {
        val gameId = newId()
        val point = PointRecord(
            id = newId(), pointNumber = 1, scorer = "player1", pointType = "winner",
            zone = "frontLeft", shotType = "drop", server = "player1",
            player1Score = 1, player2Score = 0, timestamp = 1000L, duration = 12.5,
        )
        val letCall = LetRecord(
            id = newId(), letNumber = 1, requestedBy = "player2", server = "player1",
            player1Score = 1, player2Score = 0, timestamp = 900L,
        )
        val game = GameRecord(
            id = gameId, gameNumber = 1, player1Name = "Anna", player2Name = "Bo",
            player1Score = 1, player2Score = 0, startingServer = "player1", winner = null,
            savedAt = 500L, points = listOf(point), lets = listOf(letCall),
        )
        return MatchRecord(
            id = id, player1Name = "Anna", player2Name = "Bo", matchStartingServer = "player1",
            bestOf = 5, savedAt = 500L, updatedAt = 500L, status = status,
            player1CoachingFocus = listOf("Voorhand", "Serve"), player2CoachingFocus = emptyList(),
            player1CoachingNotes = "Meer diepte spelen", player2CoachingNotes = "",
            games = listOf(game),
        )
    }

    @Test
    fun upsertRoundTripsMatchWithGamesPointsAndLets() = runTest {
        val match = sampleMatch()
        store.upsert(match)

        val loaded = store.mostRecentInProgressMatch()
        assertEquals(match.id, loaded?.id)
        assertEquals(match.player1CoachingFocus, loaded?.player1CoachingFocus)
        assertEquals(1, loaded?.games?.size)
        assertEquals(1, loaded?.games?.get(0)?.points?.size)
        assertEquals("drop", loaded?.games?.get(0)?.points?.get(0)?.shotType)
        assertEquals(1, loaded?.games?.get(0)?.lets?.size)
    }

    @Test
    fun upsertReplacesChildrenRatherThanAccumulatingThem() = runTest {
        val match = sampleMatch()
        store.upsert(match)
        // Re-upsert the same match id with one fewer point: the write path
        // must replace, not append (see MatchStore/MatchDao doc comments).
        val trimmed = match.copy(games = match.games.map { it.copy(points = emptyList()) })
        store.upsert(trimmed)

        val loaded = store.mostRecentInProgressMatch()
        assertEquals(0, loaded?.games?.get(0)?.points?.size)
    }

    @Test
    fun mostRecentInProgressMatchIgnoresCompletedAndAbandoned() = runTest {
        store.upsert(sampleMatch(status = MatchStatus.COMPLETED))
        store.upsert(sampleMatch(status = MatchStatus.ABANDONED))
        assertNull(store.mostRecentInProgressMatch())

        val inProgress = sampleMatch()
        store.upsert(inProgress)
        assertEquals(inProgress.id, store.mostRecentInProgressMatch()?.id)
    }

    @Test
    fun mostRecentInProgressMatchPicksTheLatestByUpdatedAt() = runTest {
        val older = sampleMatch().copy(updatedAt = 100L)
        val newer = sampleMatch().copy(updatedAt = 200L)
        store.upsert(older)
        store.upsert(newer)
        assertEquals(newer.id, store.mostRecentInProgressMatch()?.id)
    }

    @Test
    fun markAbandonedFlipsStatusSoItNoLongerCountsAsInProgress() = runTest {
        val match = sampleMatch()
        store.upsert(match)
        store.markAbandoned(match)
        assertNull(store.mostRecentInProgressMatch())
    }

    @Test
    fun deleteRemovesTheMatchAndCascadesToItsChildren() = runTest {
        val match = sampleMatch()
        store.upsert(match)
        store.delete(match)

        assertNull(store.mostRecentInProgressMatch())
        assertTrue(db.matchDao().gamesForMatch(match.id).isEmpty())
        assertTrue(db.matchDao().pointsForGame(match.games[0].id).isEmpty())
        assertTrue(db.matchDao().letsForGame(match.games[0].id).isEmpty())
    }
}
