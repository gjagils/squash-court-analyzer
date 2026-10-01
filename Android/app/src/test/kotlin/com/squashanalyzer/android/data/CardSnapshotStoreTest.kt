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
import skip.foundation.URL
import skip.foundation.UUID
import squash.analyzer.core.*

/** "Deel kaart" on Android must produce the same card link iOS' `CardStore.snapshot(for:)` does. */
@RunWith(RobolectricTestRunner::class)
class CardSnapshotStoreTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val filename = "card-snapshot-test.db"
    private lateinit var db: AppDatabase
    private lateinit var badgeStore: BadgeAwardStore

    @Before fun before() {
        context.deleteDatabase(filename)
        db = Room.databaseBuilder(context, AppDatabase::class.java, filename)
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6, AppDatabase.MIGRATION_6_7, AppDatabase.MIGRATION_7_8).build()
        badgeStore = BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "test-install")
    }
    @After fun after() { db.close(); context.deleteDatabase(filename) }

    private fun award(card: UUID, badge: BadgeKind, match: UUID, earnedAt: Long, deletedAt: Long? = null) = BadgeAwardEntity(
        id = AwardValue.awardId(cardId = card, badge = badge, matchId = match).uuidString,
        cardId = card.uuidString, badge = badge.rawValue, matchId = match.uuidString, earnedAt = earnedAt,
        opponentName = "Jaïr", awardedBy = "test-install", deletedAt = deletedAt)

    @Test fun snapshotCarriesTheWholeCardOldestFirstAndSurvivesTheLink() = runTest {
        val card = UUID()
        val playerId = UUID()
        db.playerDao().insert(PlayerEntity(playerId.uuidString, "Paul Stéenks", "[]", "", 0.0, cardId = card.uuidString))
        val match = UUID()
        db.badgeAwardDao().insertAll(listOf(
            award(card, BadgeKind.elevenNil, match, earnedAt = 2_000_000L),
            award(card, BadgeKind.fiveInARow, match, earnedAt = 1_000_000L),
            // Deletions travel too, so the receiver removes the badge as well
            award(card, BadgeKind.perfectTen, match, earnedAt = 3_000_000L, deletedAt = 4_000_000L),
            // Another card's award stays out
            award(UUID(), BadgeKind.offTheMark, match, earnedAt = 500_000L),
        ))

        val snapshot = badgeStore.cardSnapshot(playerId.uuidString)!!
        assertEquals(card, snapshot.cardId)
        assertEquals("Paul Stéenks", snapshot.name)

        val link = snapshot.webURL()
        assertTrue(link.absoluteString.startsWith("https://squashanalyzer.com/kaart/#"))
        val read = CardSnapshot(url = link)!!
        assertEquals(snapshot, read)

        val awards = read.awards.toList()
        assertEquals(listOf(BadgeKind.fiveInARow, BadgeKind.elevenNil, BadgeKind.perfectTen), awards.map { it.badge })
        assertEquals(1000.0, awards[0].earnedAt.timeIntervalSince1970, 0.0)
        assertNull(awards[0].deletedAt)
        assertEquals(4000.0, awards[2].deletedAt!!.timeIntervalSince1970, 0.0)
        assertEquals("Jaïr", awards[0].opponentName)
        // The receiver recomputes the same award id the sender stored
        assertEquals(AwardValue.awardId(cardId = card, badge = BadgeKind.fiveInARow, matchId = match), awards[0].id)
    }

    @Test fun aPlayerWithoutACardUsesTheirOwnId() = runTest {
        val playerId = UUID()
        db.playerDao().insert(PlayerEntity(playerId.uuidString, "Hugo", "[]", "", 0.0))
        val snapshot = badgeStore.cardSnapshot(playerId.uuidString)!!
        assertEquals(playerId, snapshot.cardId)
        assertTrue(snapshot.awards.toList().isEmpty())
    }

    @Test fun aMissingPlayerHasNoSnapshot() = runTest {
        assertNull(badgeStore.cardSnapshot(UUID().uuidString))
    }
}
