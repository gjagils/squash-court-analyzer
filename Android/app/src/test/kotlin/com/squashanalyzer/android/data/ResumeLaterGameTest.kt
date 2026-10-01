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

/** A match resumed in its third game still takes a service point and ends */
@RunWith(RobolectricTestRunner::class)
class ResumeLaterGameTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val filename = "resume-later-game.db"
    private lateinit var db: AppDatabase
    private lateinit var store: RoomCoachMatchStore

    @Before fun before() {
        context.deleteDatabase(filename)
        db = Room.databaseBuilder(context, AppDatabase::class.java, filename)
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6, AppDatabase.MIGRATION_6_7).build()
        store = RoomCoachMatchStore(MatchStore(db.matchDao()), BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "test"))
    }
    @After fun after() { db.close(); context.deleteDatabase(filename) }

    @Test fun servicePointEndsTheMatchAfterResume() = runTest {
        val match = Match()
        match.setupMatch(player1 = "A", player2 = "B", startingServer = Player.player1)
        repeat(2) {
            repeat(11) { match.currentGame.addPoint(to = Player.player1, pointType = PointType.winner, at = CourtZone.frontLeft, with = ShotType.drive) }
            match.onGameEnd()
        }
        repeat(10) { match.currentGame.addPoint(to = Player.player1, pointType = PointType.winner, at = CourtZone.backRight, with = ShotType.lob) }
        assertEquals(Player.player1, match.currentGame.currentServer)
        store.save(match)

        val resumed = store.loadInProgress()!!
        val game = resumed.currentGame
        assertEquals(3, resumed.games.count)
        assertEquals(10, game.player1Score)
        assertEquals("server after resume", Player.player1, game.currentServer)
        game.selectPlayer(Player.player1)
        game.selectPointType(PointType.servicePoint)
        assertEquals(11, game.player1Score)
        assertTrue(resumed.isMatchOver)
    }
}
