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

@RunWith(RobolectricTestRunner::class)
class BadgeAwardStoreTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val filename = "badge-award-test.db"
    private lateinit var db: AppDatabase
    private lateinit var coachAdapter: RoomCoachMatchStore
    private lateinit var badgeStore: BadgeAwardStore

    @Before fun before() {
        context.deleteDatabase(filename)
        db = Room.databaseBuilder(context, AppDatabase::class.java, filename)
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5).build()
        badgeStore = BadgeAwardStore(db.badgeAwardDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()))
        coachAdapter = RoomCoachMatchStore(MatchStore(db.matchDao()), badgeStore)
    }
    @After fun after() { db.close(); context.deleteDatabase(filename) }

    private fun point(game: Game, scorer: Player = Player.player1) {
        game.selectPlayer(scorer)
        game.selectPointType(PointType.winner)
        game.selectZone(CourtZone.frontLeft)
        game.addPoint(shotType = ShotType.drive)
    }

    @Test fun pickedPlayerEarnsAFiveInARowBadgeOnSave() = runTest {
        val match = Match()
        val player1Id = UUID()
        match.setupMatch(player1 = "Hugo", player2 = "Tegenstander", startingServer = Player.player1, player1Id = player1Id)
        repeat(5) { point(match.currentGame, Player.player1) }
        coachAdapter.save(match)

        val awards = badgeStore.activeAwards(player1Id.uuidString)
        assertTrue(awards.any { it.badge == BadgeKind.fiveInARow.rawValue })
        assertTrue(awards.all { it.matchId == match.id.uuidString })
    }

    @Test fun onlyPickedPlayersEarnBadges() = runTest {
        val match = Match()
        match.setupMatch(player1 = "Typed In", player2 = "Ook getypt", startingServer = Player.player1)
        repeat(5) { point(match.currentGame, Player.player1) }
        coachAdapter.save(match)

        // Neither player has a real id, so nothing should ever be stored.
        assertEquals(0, db.badgeAwardDao().forMatch(match.id.uuidString).size)
    }

    @Test fun undoingTheWinningRallyRetractsTheBadge() = runTest {
        val match = Match()
        val player1Id = UUID()
        match.setupMatch(player1 = "Hugo", player2 = "Tegenstander", startingServer = Player.player1, player1Id = player1Id)
        repeat(5) { point(match.currentGame, Player.player1) }
        coachAdapter.save(match)
        assertTrue(badgeStore.activeAwards(player1Id.uuidString).any { it.badge == BadgeKind.fiveInARow.rawValue })

        match.currentGame.undoLastPoint()
        coachAdapter.save(match)
        assertFalse(badgeStore.activeAwards(player1Id.uuidString).any { it.badge == BadgeKind.fiveInARow.rawValue })
    }
}
