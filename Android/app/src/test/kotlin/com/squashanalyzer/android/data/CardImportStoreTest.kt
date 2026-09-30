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
import skip.foundation.Date
import skip.foundation.UUID
import skip.lib.Array as SwiftArray
import squash.analyzer.core.*

/** Importing a card link must behave like iOS' `CardStore`: link, move own awards, merge, deletion wins. */
@RunWith(RobolectricTestRunner::class)
class CardImportStoreTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val filename = "card-import-test.db"
    private lateinit var db: AppDatabase
    private lateinit var store: BadgeAwardStore

    private val card = UUID()
    private val match = UUID()

    @Before fun before() {
        context.deleteDatabase(filename)
        db = Room.databaseBuilder(context, AppDatabase::class.java, filename)
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6).build()
        store = BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "this-install")
    }
    @After fun after() { db.close(); context.deleteDatabase(filename) }

    private fun value(badge: BadgeKind, cardId: UUID = card, deletedAt: Double? = null) = AwardValue(
        cardId = cardId, badge = badge, matchId = match, earnedAt = Date(timeIntervalSince1970 = 1_790_000_000.0),
        opponentName = "Jaïr", awardedBy = "other-install", deletedAt = deletedAt?.let { Date(timeIntervalSince1970 = it) })

    private fun snapshot(vararg awards: AwardValue) = CardSnapshot(cardId = card, name = "Paul", awards = SwiftArray(awards.toList()))

    private suspend fun player(name: String, cardId: String? = null): String {
        val id = UUID().uuidString
        db.playerDao().insert(PlayerEntity(id, name, "[]", "", 0.0, cardId = cardId))
        return id
    }

    private suspend fun ownAward(playerId: String, badge: BadgeKind) {
        val own = UUID(uuidString = playerId)!!
        db.badgeAwardDao().insertAll(listOf(BadgeAwardEntity(
            id = AwardValue.awardId(cardId = own, badge = badge, matchId = match).uuidString, cardId = playerId,
            badge = badge.rawValue, matchId = match.uuidString, earnedAt = 1_000L, opponentName = "", awardedBy = "this-install")))
    }

    @Test fun importingToANewPlayerCreatesThemOnTheCard() = runTest {
        store.importCard(snapshot(value(BadgeKind.fiveInARow), value(BadgeKind.elevenNil, deletedAt = 1_790_000_100.0)), null)

        val paul = db.playerDao().all().single { it.name == "Paul" }
        assertEquals(card.uuidString, paul.cardId)
        assertEquals(listOf(BadgeKind.fiveInARow), store.badges(paul.id).toList())
        val rows = db.badgeAwardDao().forCard(card.uuidString)
        assertEquals(2, rows.size)
        // The deletion is kept, so it can travel on in this device's links
        assertEquals(1_790_000_100_000L, rows.single { it.badge == BadgeKind.elevenNil.rawValue }.deletedAt)
        assertEquals("other-install", rows.first().awardedBy)
        assertEquals(1_790_000_000_000L, rows.first().earnedAt)
    }

    @Test fun linkingMovesThePlayersOwnAwardsOntoTheCard() = runTest {
        val hugo = player("Hugo")
        ownAward(hugo, BadgeKind.houdini)

        store.importCard(snapshot(value(BadgeKind.fiveInARow)), hugo)

        assertEquals(card.uuidString, db.playerDao().byId(hugo)!!.cardId)
        assertTrue(db.badgeAwardDao().forCard(hugo).isEmpty())
        val onCard = db.badgeAwardDao().forCard(card.uuidString)
        assertEquals(setOf(BadgeKind.houdini.rawValue, BadgeKind.fiveInARow.rawValue), onCard.map { it.badge }.toSet())
        val moved = onCard.single { it.badge == BadgeKind.houdini.rawValue }
        assertEquals(AwardValue.awardId(cardId = card, badge = BadgeKind.houdini, matchId = match).uuidString, moved.id)
    }

    @Test fun aDeletionAlwaysWins() = runTest {
        val hugo = player("Hugo", cardId = card.uuidString)
        store.importCard(snapshot(value(BadgeKind.fiveInARow), value(BadgeKind.elevenNil)), hugo)
        // The card deletes one badge, and brings back one this device deleted
        db.badgeAwardDao().markDeleted(value(BadgeKind.elevenNil).id.uuidString, 5_000L)
        store.importCard(snapshot(value(BadgeKind.fiveInARow, deletedAt = 1_790_000_200.0), value(BadgeKind.elevenNil)), hugo)

        assertTrue(store.badges(hugo).toList().isEmpty())
        assertEquals(5_000L, db.badgeAwardDao().byId(value(BadgeKind.elevenNil).id.uuidString)!!.deletedAt)
    }

    @Test fun previewCountsWhatChangesAndFindsTheLinkedPlayer() = runTest {
        val other = player("Paul")
        val first = store.importPreview(snapshot(value(BadgeKind.fiveInARow), value(BadgeKind.elevenNil, deletedAt = 1.0)))
        assertEquals(1, first.activeBadges)
        assertEquals(1, first.newBadges)
        assertEquals(0, first.deletedBadges)
        assertNull(first.linkedPlayer)
        assertEquals(listOf(other), first.players.toList().map { it.id })

        store.importCard(snapshot(value(BadgeKind.fiveInARow)), other)
        val again = store.importPreview(snapshot(value(BadgeKind.fiveInARow, deletedAt = 2.0)))
        assertEquals(0, again.newBadges)
        assertEquals(1, again.deletedBadges)
        assertEquals(other, again.linkedPlayer?.id)
        assertEquals("0 badges op de kaart · 1 verwijderd", again.summary)
    }
}
