package com.squashanalyzer.android.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import squash.analyzer.core.*

@RunWith(RobolectricTestRunner::class)
class RoomMatchHistoryStoreTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val filename = "match-history-test.db"
    private lateinit var db: AppDatabase
    private lateinit var coachAdapter: RoomCoachMatchStore
    private lateinit var refereeAdapter: RoomRefereeMatchStore
    private lateinit var history: RoomMatchHistoryStore

    @Before fun before() {
        context.deleteDatabase(filename)
        db = Room.databaseBuilder(context, AppDatabase::class.java, filename)
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6, AppDatabase.MIGRATION_6_7).build()
        val badgeStore = BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "test-install")
        val coachStore = MatchStore(db.matchDao())
        val refereeStore = RefereeMatchStore(db.refereeMatchDao())
        coachAdapter = RoomCoachMatchStore(coachStore, badgeStore)
        refereeAdapter = RoomRefereeMatchStore(refereeStore, badgeStore)
        history = RoomMatchHistoryStore(coachStore, refereeStore, coachAdapter, refereeAdapter, badgeStore)
    }
    @After fun after() { db.close(); context.deleteDatabase(filename) }

    private fun point(game: Game, scorer: Player = Player.player1) {
        game.selectPlayer(scorer)
        game.selectPointType(PointType.winner)
        game.selectZone(CourtZone.frontLeft)
        game.addPoint(shotType = ShotType.drive)
    }

    @Test fun inProgressMatchesAreExcludedFromHistory() = runTest {
        val match = Match()
        point(match.currentGame)
        coachAdapter.save(match)
        assertTrue(history.loadHistory().isEmpty)
    }

    @Test fun completedAndAbandonedMatchesFromBothModesAreMergedAndSorted() = runTest {
        // Match.games seeds the in-progress game up front and Game.winner is
        // computed from score, so winning all 3 rallies already counts as 3
        // games won even though onGameEnd() is only called between games.
        val completedCoach = Match()
        completedCoach.setupMatch(player1 = "Coach1", player2 = "Coach2", startingServer = Player.player1)
        repeat(3) { game ->
            repeat(11) { point(completedCoach.currentGame) }
            if (game < 2) completedCoach.onGameEnd()
        }
        coachAdapter.save(completedCoach)

        val abandonedReferee = RefereeMatch(player1Name = "Ref1", player2Name = "Ref2", bestOf = 5, startingServer = Player.player1)
        abandonedReferee.awardPoint(to = Player.player2)
        refereeAdapter.abandon(abandonedReferee)

        val entries = history.loadHistory().toList()
        assertEquals(2, entries.size)
        val coachEntry = entries.first { it.kind == "coach" }
        assertEquals("Coach1", coachEntry.player1Name)
        assertEquals("completed", coachEntry.status)
        assertEquals(3, coachEntry.player1Games)
        assertEquals(0, coachEntry.player2Games)

        val refereeEntry = entries.first { it.kind == "referee" }
        assertEquals("Ref1", refereeEntry.player1Name)
        assertEquals("abandoned", refereeEntry.status)
        assertEquals(0, refereeEntry.player1Games)
        assertEquals(0, refereeEntry.player2Games)
    }

    @Test fun anIncompleteMatchCanBeOpenedCompletedAndDeleted() = runTest {
        val match = Match()
        match.setupMatch(player1 = "Gerard", player2 = "Thé", startingServer = Player.player1, player1GamesBefore = 1)
        repeat(11) { point(match.currentGame) }
        match.onGameEnd()
        point(match.currentGame, Player.player2)
        coachAdapter.save(match)
        coachAdapter.abandon(match)

        val row = history.loadHistory().single()
        assertEquals("abandoned", row.status)
        assertEquals(2, row.player1Games)

        val opened = history.coachMatch(row.id)!!
        assertEquals(1, opened.games[1].player2Score)
        assertTrue(opened.completeResult(with = skip.lib.Array(listOf(Player.player1))))
        history.saveCoachMatch(opened)
        val completed = history.loadHistory().single()
        assertEquals("completed", completed.status)
        assertEquals(3, completed.player1Games)

        history.delete(completed)
        assertTrue(history.loadHistory().isEmpty)
        assertNull(history.coachMatch(row.id))
    }
}
