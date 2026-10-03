package com.squashanalyzer.android.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import skip.lib.Array as SwiftArray
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import skip.foundation.UUID
import squash.analyzer.core.*

/** Awards must match iOS' `BadgeAwarder` exactly, or card links would not merge. */
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
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6, AppDatabase.MIGRATION_6_7, AppDatabase.MIGRATION_7_8, AppDatabase.MIGRATION_8_9).build()
        badgeStore = BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "test-install")
        coachAdapter = RoomCoachMatchStore(MatchStore(db.matchDao()), badgeStore)
    }
    @After fun after() { db.close(); context.deleteDatabase(filename) }

    private suspend fun player(name: String = "Hugo", cardId: String? = null): UUID {
        val id = UUID()
        db.playerDao().insert(PlayerEntity(id = id.uuidString, name = name, coachingFocusAreas = "[]", coachingNotes = "", createdAt = 0.0, cardId = cardId))
        return id
    }

    private fun point(game: Game, scorer: Player = Player.player1) {
        game.selectPlayer(scorer)
        game.selectPointType(PointType.winner)
        game.selectZone(CourtZone.frontLeft)
        game.addPoint(shotType = ShotType.drive)
    }

    private fun matchWithFiveInARow(player1Id: UUID?): Match {
        val match = Match()
        match.setupMatch(player1 = "Hugo", player2 = "Tegenstander", startingServer = Player.player1, player1Id = player1Id)
        repeat(5) { point(match.currentGame, Player.player1) }
        return match
    }

    @Test fun pickedPlayerEarnsABadgeWithTheIOSAwardIdOnTheirCard() = runTest {
        val playerId = player()
        val match = matchWithFiveInARow(playerId)
        coachAdapter.save(match)

        val award = badgeStore.activeAwards(playerId.uuidString).single { it.badge == BadgeKind.fiveInARow.rawValue }
        assertEquals(playerId.uuidString, award.cardId)
        assertEquals(AwardValue.awardId(cardId = playerId, badge = BadgeKind.fiveInARow, matchId = match.id).uuidString, award.id)
        assertEquals(match.id.uuidString, award.matchId)
        assertEquals("Tegenstander", award.opponentName)
        assertEquals("test-install", award.awardedBy)
    }

    @Test fun awardsLandOnTheLinkedCardWhenThePlayerHasOne() = runTest {
        val card = UUID()
        val playerId = player(cardId = card.uuidString)
        val match = matchWithFiveInARow(playerId)
        coachAdapter.save(match)

        val award = badgeStore.activeAwards(playerId.uuidString).single { it.badge == BadgeKind.fiveInARow.rawValue }
        assertEquals(card.uuidString, award.cardId)
        assertEquals(AwardValue.awardId(cardId = card, badge = BadgeKind.fiveInARow, matchId = match.id).uuidString, award.id)
    }

    @Test fun onlyKnownPickedPlayersEarnBadges() = runTest {
        val typedIn = matchWithFiveInARow(null)
        coachAdapter.save(typedIn)
        assertTrue(db.badgeAwardDao().forMatch(typedIn.id.uuidString).isEmpty())

        // An id without a player row earns nothing either, like iOS (no card to put it on)
        val unknown = matchWithFiveInARow(UUID())
        coachAdapter.save(unknown)
        assertTrue(db.badgeAwardDao().forMatch(unknown.id.uuidString).isEmpty())
    }

    @Test fun undoingTheWinningRallyRemovesTheAwardOutright() = runTest {
        val playerId = player()
        val match = matchWithFiveInARow(playerId)
        coachAdapter.save(match)
        assertEquals(1, db.badgeAwardDao().forMatch(match.id.uuidString).count { it.badge == BadgeKind.fiveInARow.rawValue })

        match.currentGame.undoLastPoint()
        coachAdapter.save(match)
        // Removed, not marked deleted: it was never really earned, so it must not travel as a deletion
        assertTrue(db.badgeAwardDao().forMatch(match.id.uuidString).none { it.badge == BadgeKind.fiveInARow.rawValue })
    }

    @Test fun aDeletedAwardStaysDeletedWhenTheMatchIsSavedAgain() = runTest {
        val playerId = player()
        val match = matchWithFiveInARow(playerId)
        coachAdapter.save(match)
        val award = db.badgeAwardDao().forMatch(match.id.uuidString).single { it.badge == BadgeKind.fiveInARow.rawValue }
        db.badgeAwardDao().deleteByIds(listOf(award.id))
        db.badgeAwardDao().insertAll(listOf(award.copy(deletedAt = 1_000L)))

        point(match.currentGame, Player.player1)
        coachAdapter.save(match)

        val after = db.badgeAwardDao().forMatch(match.id.uuidString).single { it.badge == BadgeKind.fiveInARow.rawValue }
        assertEquals(1_000L, after.deletedAt)
        assertTrue(badgeStore.activeAwards(playerId.uuidString).none { it.badge == BadgeKind.fiveInARow.rawValue })
    }

    @Test fun momentsListWhenAndAgainstWhomAndADeletedOneIsGone() = runTest {
        val playerId = player()
        coachAdapter.save(matchWithFiveInARow(playerId))

        val moment = badgeStore.moments(playerId.uuidString).toList().single { it.badge == BadgeKind.fiveInARow }
        assertEquals("Tegenstander", moment.opponentName)
        badgeStore.deleteMoment(moment.id)
        assertTrue(badgeStore.moments(playerId.uuidString).toList().none { it.id == moment.id })
        // The deletion travels with the next shared card
        val card = badgeStore.cardSnapshot(playerId.uuidString)!!
        assertTrue(card.awards.toList().any { it.deletedAt != null })
    }

    /** The player list counts every player's badges in one go, the same as badges(forPlayer:) one by one */
    @Test fun badgeCountsMatchThePerPlayerCount() = runTest {
        val hugo = player()
        val linked = player(name = "Kaart", cardId = UUID().uuidString)
        val none = player(name = "Leeg")
        coachAdapter.save(matchWithFiveInARow(hugo))
        coachAdapter.save(matchWithFiveInARow(linked))

        val ids = listOf(hugo, linked, none).map { it.uuidString }
        val counts = badgeStore.badgeCounts(forPlayers = SwiftArray(ids))
        for (id in ids) assertEquals(badgeStore.badges(forPlayer = id).count, counts[id])
        assertTrue(counts[hugo.uuidString]!! > 0)
        assertEquals(0, counts[none.uuidString])
    }
}
