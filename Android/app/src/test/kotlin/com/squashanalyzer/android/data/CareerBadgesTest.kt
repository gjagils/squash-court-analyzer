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

/**
 * `BadgeKind.isCareer` badges are stored with the match that earned them, like
 * iOS' `BadgeAwarder`, so they travel in card links with the other awards.
 */
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
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6, AppDatabase.MIGRATION_6_7).build()
        val coachStore = MatchStore(db.matchDao())
        val refereeStore = RefereeMatchStore(db.refereeMatchDao())
        badgeStore = BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), coachStore, refereeStore, "test-install")
        coachAdapter = RoomCoachMatchStore(coachStore, badgeStore)
    }
    @After fun after() { db.close(); context.deleteDatabase(filename) }

    private suspend fun player(): UUID {
        val id = UUID()
        db.playerDao().insert(PlayerEntity(id = id.uuidString, name = "Hugo", coachingFocusAreas = "[]", coachingNotes = "", createdAt = 0.0))
        return id
    }

    private fun point(game: Game, scorer: Player = Player.player1) {
        game.selectPlayer(scorer)
        game.selectPointType(PointType.winner)
        game.selectZone(CourtZone.frontLeft)
        game.addPoint(shotType = ShotType.drive)
    }

    private suspend fun playAndSaveAWin(playerId: UUID): Match {
        val match = Match()
        match.setupMatch(player1 = "Hugo", player2 = "Tegenstander", startingServer = Player.player1, player1Id = playerId)
        repeat(3) { game ->
            repeat(11) { point(match.currentGame, Player.player1) }
            if (game < 2) match.onGameEnd()
        }
        coachAdapter.save(match)
        return match
    }

    private suspend fun awardsOf(playerId: UUID, badge: BadgeKind) =
        badgeStore.activeAwards(playerId.uuidString).filter { it.badge == badge.rawValue }

    @Test fun firstWinStoresOffTheMarkWithThatMatch() = runTest {
        val playerId = player()
        val match = playAndSaveAWin(playerId)
        val award = awardsOf(playerId, BadgeKind.offTheMark).single()
        assertEquals(match.id.uuidString, award.matchId)
        assertTrue(badgeStore.badges(playerId.uuidString).toList().contains(BadgeKind.offTheMark))
    }

    @Test fun onceOnlyBadgesAreNotAwardedAgain() = runTest {
        val playerId = player()
        playAndSaveAWin(playerId)
        playAndSaveAWin(playerId)
        assertEquals(1, awardsOf(playerId, BadgeKind.offTheMark).size)
    }

    @Test fun threeWinsInARowStoreHatTrickWithTheThirdMatch() = runTest {
        val playerId = player()
        playAndSaveAWin(playerId)
        playAndSaveAWin(playerId)
        val third = playAndSaveAWin(playerId)
        assertEquals(listOf(third.id.uuidString), awardsOf(playerId, BadgeKind.hatTrick).map { it.matchId })
    }

    @Test fun anUndecidedMatchEarnsNoCareerBadges() = runTest {
        val playerId = player()
        val match = Match()
        match.setupMatch(player1 = "Hugo", player2 = "Tegenstander", startingServer = Player.player1, player1Id = playerId)
        repeat(11) { point(match.currentGame, Player.player1) }
        coachAdapter.save(match)
        assertTrue(awardsOf(playerId, BadgeKind.offTheMark).isEmpty())
    }

    @Test fun careerBadgesDoNotLeakToAnUninvolvedPlayer() = runTest {
        val playerId = player()
        val stranger = player()
        playAndSaveAWin(playerId)
        assertTrue(badgeStore.badges(stranger.uuidString).toList().isEmpty())
    }
}
