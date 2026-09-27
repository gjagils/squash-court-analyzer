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
import skip.foundation.UUID
import squash.analyzer.core.*

/** `BadgeKind.isCareer` badges, computed live from a player's whole match history. */
@RunWith(RobolectricTestRunner::class)
class CareerBadgesTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val filename = "career-badges-test.db"
    private lateinit var db: AppDatabase
    private lateinit var coachAdapter: RoomCoachMatchStore
    private lateinit var badgeStore: BadgeAwardStore

    @Before fun before() {
        context.deleteDatabase(filename)
        db = Room.databaseBuilder(context, AppDatabase::class.java, filename)
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5).build()
        val coachStore = MatchStore(db.matchDao())
        val refereeStore = RefereeMatchStore(db.refereeMatchDao())
        badgeStore = BadgeAwardStore(db.badgeAwardDao(), coachStore, refereeStore)
        coachAdapter = RoomCoachMatchStore(coachStore, badgeStore)
    }
    @After fun after() { db.close(); context.deleteDatabase(filename) }

    private fun point(game: Game, scorer: Player = Player.player1) {
        game.selectPlayer(scorer)
        game.selectPointType(PointType.winner)
        game.selectZone(CourtZone.frontLeft)
        game.addPoint(shotType = ShotType.drive)
    }

    private suspend fun playAndSaveAWin(playerId: UUID) {
        val match = Match()
        match.setupMatch(player1 = "Hugo", player2 = "Tegenstander", startingServer = Player.player1, player1Id = playerId)
        repeat(3) { game ->
            repeat(11) { point(match.currentGame, Player.player1) }
            if (game < 2) match.onGameEnd()
        }
        coachAdapter.save(match)
    }

    @Test fun firstWinEarnsOffTheMark() = runTest {
        val playerId = UUID()
        playAndSaveAWin(playerId)
        val badges = badgeStore.badges(playerId.uuidString).toList()
        assertTrue(badges.contains(BadgeKind.offTheMark))
    }

    @Test fun threeWinsInARowEarnHatTrick() = runTest {
        val playerId = UUID()
        repeat(3) { playAndSaveAWin(playerId) }
        val badges = badgeStore.badges(playerId.uuidString).toList()
        assertTrue(badges.contains(BadgeKind.hatTrick))
    }

    @Test fun careerBadgesDoNotLeakToAnUninvolvedPlayer() = runTest {
        val playerId = UUID()
        val strangerId = UUID()
        playAndSaveAWin(playerId)
        val strangerBadges = badgeStore.badges(strangerId.uuidString).toList()
        assertTrue(strangerBadges.isEmpty())
    }
}
