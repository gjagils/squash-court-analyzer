package com.squashanalyzer.android.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import squash.analyzer.core.*

/** Version 9 adds the kind of unforced error; points saved by 0.3 (version 8) keep working. */
@RunWith(RobolectricTestRunner::class)
class ErrorKindMigrationTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val filename = "errorkind-migration-test.db"
    private lateinit var db: AppDatabase

    private fun open() {
        db = Room.databaseBuilder(context, AppDatabase::class.java, filename)
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6, AppDatabase.MIGRATION_6_7, AppDatabase.MIGRATION_7_8, AppDatabase.MIGRATION_8_9)
            .allowMainThreadQueries().build()
    }
    @Before fun before() { context.deleteDatabase(filename); open() }
    @After fun after() { db.close(); context.deleteDatabase(filename) }

    private fun coachStore() = RoomCoachMatchStore(MatchStore(db.matchDao()),
        BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "test"))

    @Test fun versionEightPointsGetAnUnknownKind() = runTest {
        val match = Match()
        match.player1Name = "Jan"
        match.player2Name = "Piet"
        match.currentGame.addPoint(to = Player.player1, pointType = PointType.unforcedError, at = null, with = null)
        coachStore().save(match)
        db.close()

        // Rewind to the 0.3 database: no errorKind column
        SQLiteDatabase.openDatabase(context.getDatabasePath(filename).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            it.execSQL("ALTER TABLE points DROP COLUMN errorKind")
            it.version = 8
        }
        open()

        val resumed = coachStore().loadInProgress()!!
        assertEquals(1, resumed.currentGame.player1Score)
        assertNull(resumed.currentGame.points.toList().single().errorKind)

        // And a new error with a kind saves after the migration
        resumed.currentGame.addPoint(to = Player.player1, pointType = PointType.unforcedError, at = null, with = null, errorKind = ErrorKind.outOfCourt)
        coachStore().save(resumed)
        assertEquals(ErrorKind.outOfCourt, coachStore().loadInProgress()!!.currentGame.points.toList().last().errorKind)
    }
}
