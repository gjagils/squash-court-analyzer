package com.squashanalyzer.android.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
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
import squash.analyzer.core.AwardValue
import squash.analyzer.core.BadgeKind

/** Version 5 stored awards per player with a local id; version 6 uses the iOS shape. */
@RunWith(RobolectricTestRunner::class)
class BadgeAwardMigrationTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val filename = "badge-migration-test.db"
    private lateinit var db: AppDatabase

    private fun open() {
        db = Room.databaseBuilder(context, AppDatabase::class.java, filename)
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6, AppDatabase.MIGRATION_6_7, AppDatabase.MIGRATION_7_8, AppDatabase.MIGRATION_8_9).build()
    }
    @Before fun before() { context.deleteDatabase(filename); open() }
    @After fun after() { db.close(); context.deleteDatabase(filename) }

    @Test fun versionFiveAwardsMoveToTheCardWithTheIOSAwardId() = runTest {
        val plain = "0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2"
        val linked = "1B2C3D4E-5F60-4718-8293-A4B5C6D7E8F9"
        val card = "9F8E7D6C-5B4A-4392-8180-706F5E4D3C2B"
        val match = "11111111-2222-4333-8444-555555555555"
        db.playerDao().insert(PlayerEntity(plain, "Plain", "[]", "", 0.0))
        db.playerDao().insert(PlayerEntity(linked, "Linked", "[]", "", 0.0, cardId = card))
        db.close()

        SQLiteDatabase.openDatabase(context.getDatabasePath(filename).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("DROP TABLE badge_awards")
            it.execSQL("CREATE TABLE badge_awards (id TEXT NOT NULL PRIMARY KEY, playerId TEXT NOT NULL, badge TEXT NOT NULL, matchId TEXT NOT NULL, earnedAt INTEGER NOT NULL, deletedAt INTEGER)")
            it.execSQL("INSERT INTO badge_awards VALUES ('$plain:five-in-a-row:$match', '$plain', 'five-in-a-row', '$match', 1000, NULL)")
            it.execSQL("INSERT INTO badge_awards VALUES ('$linked:eleven-nil:$match', '$linked', 'eleven-nil', '$match', 2000, NULL)")
            // A retraction from the old undo behaviour: dropped, not carried over as a deletion
            it.execSQL("INSERT INTO badge_awards VALUES ('$plain:perfect-ten:$match', '$plain', 'perfect-ten', '$match', 3000, 4000)")
            // A badge this build does not know: skipped
            it.execSQL("INSERT INTO badge_awards VALUES ('$plain:no-such-badge:$match', '$plain', 'no-such-badge', '$match', 5000, NULL)")
            it.version = 5
        }
        open()

        val rows = db.badgeAwardDao().forMatch(match).sortedBy { it.earnedAt }
        assertEquals(2, rows.size)

        val first = rows[0]
        assertEquals(plain, first.cardId)
        assertEquals("five-in-a-row", first.badge)
        assertEquals(1000L, first.earnedAt)
        assertNull(first.deletedAt)
        assertEquals(AwardValue.awardId(cardId = UUID(uuidString = plain)!!, badge = BadgeKind.fiveInARow, matchId = UUID(uuidString = match)!!).uuidString, first.id)

        val second = rows[1]
        assertEquals(card, second.cardId)
        assertEquals(AwardValue.awardId(cardId = UUID(uuidString = card)!!, badge = BadgeKind.elevenNil, matchId = UUID(uuidString = match)!!).uuidString, second.id)
    }
}
