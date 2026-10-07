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

/**
 * Steps 6→7 (the volley switch on points) and 7→8 (the opening serve of a
 * referee game): a database of that version is made by rewinding a current
 * one (dropping the columns of the later steps, as ErrorKindMigrationTest
 * does), then opened again through all migrations.
 */
@RunWith(RobolectricTestRunner::class)
class VolleyAndOpeningServeMigrationTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val filename = "volley-opening-migration-test.db"
    private lateinit var db: AppDatabase

    private fun open() {
        db = Room.databaseBuilder(context, AppDatabase::class.java, filename)
            .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6, AppDatabase.MIGRATION_6_7, AppDatabase.MIGRATION_7_8, AppDatabase.MIGRATION_8_9)
            .allowMainThreadQueries().build()
    }
    @Before fun before() { context.deleteDatabase(filename); open() }
    @After fun after() { db.close(); context.deleteDatabase(filename) }

    private fun badges() = BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "test")
    private fun coachStore() = RoomCoachMatchStore(MatchStore(db.matchDao()), badges())
    private fun refereeStore() = RoomRefereeMatchStore(RefereeMatchStore(db.refereeMatchDao()), badges())

    /** Back to `version` with the columns of the later steps removed */
    private fun rewind(version: Int, drops: List<String>) {
        db.close()
        SQLiteDatabase.openDatabase(context.getDatabasePath(filename).path, null, SQLiteDatabase.OPEN_READWRITE).use {
            for (drop in drops) it.execSQL(drop)
            it.version = version
        }
        open()
    }

    private val afterEight = listOf("ALTER TABLE points DROP COLUMN errorKind")
    private val afterSeven = afterEight + listOf(
        "ALTER TABLE referee_matches DROP COLUMN openingServer",
        "ALTER TABLE referee_matches DROP COLUMN openingSide",
    )
    private val afterSix = afterSeven + listOf("ALTER TABLE points DROP COLUMN isVolley")

    @Test fun versionSixPointsBecomeNoVolleys() = runTest {
        val match = Match()
        match.player1Name = "Jan"
        match.player2Name = "Piet"
        match.currentGame.addPoint(to = Player.player1, pointType = PointType.winner, at = null, with = ShotType.drop, isVolley = true)
        match.currentGame.addPoint(to = Player.player2, pointType = PointType.unforcedError, at = null, with = null)
        coachStore().save(match)

        rewind(6, afterSix)

        val resumed = coachStore().loadInProgress()!!
        assertEquals(1, resumed.currentGame.player1Score)
        assertEquals(1, resumed.currentGame.player2Score)
        // The column did not exist in version 6: every point was no volley
        assertTrue(resumed.currentGame.points.toList().none { it.isVolley })

        // A volley saves after the migration
        resumed.currentGame.addPoint(to = Player.player1, pointType = PointType.winner, at = null, with = ShotType.drive, isVolley = true)
        coachStore().save(resumed)
        assertTrue(coachStore().loadInProgress()!!.currentGame.points.toList().last().isVolley)
    }

    @Test fun versionSevenRefereeMatchResumesWithoutOpeningServe() = runTest {
        val match = RefereeMatch(player1Name = "Hugo", player2Name = "Tegenstander", bestOf = 5, startingServer = Player.player1)
        match.awardPoint(to = Player.player1)
        match.awardPoint(to = Player.player2)
        refereeStore().save(match)

        rewind(7, afterSeven)

        val stored = db.refereeMatchDao().matchById(match.id.uuidString)!!
        assertNull(stored.openingServer)
        val resumed = refereeStore().loadInProgress()!!
        assertEquals(match.id, resumed.id)
        assertEquals(1, resumed.player1Score)
        assertEquals(1, resumed.player2Score)
        assertEquals(Player.player2, resumed.currentServer)

        // Scoring and saving go on after the migration
        resumed.awardPoint(to = Player.player2)
        refereeStore().save(resumed)
        assertEquals(2, refereeStore().loadInProgress()!!.player2Score)
    }
}
