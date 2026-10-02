package com.squashanalyzer.android.data

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import skip.foundation.Data
import skip.foundation.UUID
import squash.analyzer.core.*

/**
 * Backups on Android: a file made by the iOS app restores here, and a backup
 * made here restores into an empty install (the same file format both ways).
 */
@RunWith(RobolectricTestRunner::class)
class RoomBackupStoreTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val names = listOf("backup-a.db", "backup-b.db")
    private lateinit var a: AppDatabase
    private lateinit var b: AppDatabase

    private fun open(name: String) = Room.databaseBuilder(context, AppDatabase::class.java, name)
        .addMigrations(AppDatabase.MIGRATION_1_2, AppDatabase.MIGRATION_2_3, AppDatabase.MIGRATION_3_4, AppDatabase.MIGRATION_4_5, AppDatabase.MIGRATION_5_6, AppDatabase.MIGRATION_6_7, AppDatabase.MIGRATION_7_8, AppDatabase.MIGRATION_8_9)
        .allowMainThreadQueries().build()

    @Before fun before() {
        names.forEach { context.deleteDatabase(it) }
        a = open(names[0])
        b = open(names[1])
    }
    @After fun after() {
        a.close(); b.close()
        names.forEach { context.deleteDatabase(it) }
    }

    private fun iosFile(): Data {
        val bytes = requireNotNull(javaClass.classLoader!!.getResourceAsStream("ios-backup.json")).readBytes()
        return Data(platformValue = bytes)
    }

    private fun coachStore(db: AppDatabase) = RoomCoachMatchStore(MatchStore(db.matchDao()),
        BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "test"))

    @Test fun anIOSBackupRestoresOnAndroid() = runTest {
        val backup = BackupCodec.decode(iosFile())
        val counts = RoomBackupStore(a).restore(backup, replacing = false)
        assertEquals(BackupCounts(players = 1, matches = 2, games = 2, badges = 1), counts)

        val player = a.playerDao().byId("0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2")!!
        assertEquals("Paul Stéenks", player.name)

        val all = MatchStore(a.matchDao()).all()
        val match = all.single { it.id == "6F1C2B3A-4D5E-4F60-8A7B-9C0D1E2F3A4B" }
        assertEquals("Let op \"lengte\" / tempo", match.player1CoachingNotes)
        assertEquals(listOf("Backhand", "Drop"), match.player1CoachingFocus)
        assertEquals(1, match.player1GamesBefore)
        assertEquals(2, match.games.single().points.size)
        assertEquals(1, match.games.single().lets.size)

        // The old iOS "Ace" shot became a service point; the loose game a finished match
        val loose = all.single { it.player1Name == "Oud" }
        assertEquals(MatchStatus.COMPLETED, loose.status)
        val ace = loose.games.single().points.single()
        assertEquals(PointType.servicePoint.rawValue, ace.pointType)
        assertEquals("", ace.shotType)

        // And the restored matches open in the history like any other
        assertEquals(2, RoomMatchHistoryStore(MatchStore(a.matchDao()), RefereeMatchStore(a.refereeMatchDao()), coachStore(a),
            RoomRefereeMatchStore(RefereeMatchStore(a.refereeMatchDao()), BadgeAwardStore(a.badgeAwardDao(), a.playerDao(), MatchStore(a.matchDao()), RefereeMatchStore(a.refereeMatchDao()), "test")),
            BadgeAwardStore(a.badgeAwardDao(), a.playerDao(), MatchStore(a.matchDao()), RefereeMatchStore(a.refereeMatchDao()), "test")).loadHistory().count)
    }

    @Test fun anAndroidBackupRoundTripsIntoAnEmptyInstall() = runTest {
        a.playerDao().insert(PlayerEntity("1B2C3D4E-5F60-4718-8293-A4B5C6D7E8F9", "Hugo", "[\"Drop\"]", "Notitie", 1_790_000_000.0,
            photoData = byteArrayOf(1, 2, 3)))
        val match = Match()
        match.setupMatch(player1 = "Hugo", player2 = "Jaïr", startingServer = Player.player1,
            player1Id = UUID(uuidString = "1B2C3D4E-5F60-4718-8293-A4B5C6D7E8F9"))
        repeat(5) { match.currentGame.addPoint(to = Player.player1, pointType = PointType.winner, at = CourtZone.frontLeft, with = ShotType.drive) }
        match.currentGame.addPoint(to = Player.player1, pointType = PointType.winner, at = CourtZone.frontRight, with = ShotType.kill, isVolley = true)
        match.currentGame.addPoint(to = Player.player2, pointType = PointType.unforcedError, at = null, with = null, errorKind = ErrorKind.viaFloor)
        match.currentGame.addLet(requestedBy = Player.player2)
        coachStore(a).save(match)
        assertTrue(a.badgeAwardDao().all().isNotEmpty())

        val file = BackupCodec.encode(RoomBackupStore(a).makeBackup(), appVersion = "android-test")
        val counts = RoomBackupStore(b).restore(BackupCodec.decode(file), replacing = true)
        assertEquals(1, counts.players)
        assertEquals(1, counts.matches)
        assertEquals(a.badgeAwardDao().all().size, counts.badges)

        val restoredPlayer = b.playerDao().byId("1B2C3D4E-5F60-4718-8293-A4B5C6D7E8F9")!!
        assertArrayEquals(byteArrayOf(1, 2, 3), restoredPlayer.photoData)
        assertEquals("Notitie", restoredPlayer.coachingNotes)
        val resumed = coachStore(b).loadInProgress()!!
        assertEquals(match.id, resumed.id)
        assertEquals(6, resumed.currentGame.player1Score)
        assertEquals(1, resumed.currentGame.player2Score)
        assertEquals(1, resumed.currentGame.lets.count)
        assertEquals(match.player1Id, resumed.player1Id)
        // The volley switch, Kill and the kind of unforced error survive Room → backup file → Room
        val points = resumed.currentGame.points.toList()
        val kill = points[points.size - 2]
        assertEquals(ShotType.kill, kill.shotType)
        assertTrue(kill.isVolley)
        assertEquals(ErrorKind.viaFloor, points.last().errorKind)
        assertTrue(resumed.currentGame.isStarted)
    }

    @Test fun mergingKeepsWhatIsThereAndADeletionWins() = runTest {
        val backup = BackupCodec.decode(iosFile())
        RoomBackupStore(a).restore(backup, replacing = false)
        val award = a.badgeAwardDao().all().single()
        a.badgeAwardDao().markDeleted(award.id, 5_000L)
        a.playerDao().updateFields("0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2", "Paul (eigen)", "[]", "")

        val again = RoomBackupStore(a).restore(backup, replacing = false)
        assertEquals(BackupCounts(players = 0, matches = 0, games = 0, badges = 0), again)
        assertEquals("Paul (eigen)", a.playerDao().byId("0A3C7E1D-2B44-4F10-9C3A-5D6E7F8091A2")!!.name)
        assertEquals(5_000L, a.badgeAwardDao().byId(award.id)!!.deletedAt)
    }

    @Test fun replacingStartsFromTheBackupOnly() = runTest {
        a.playerDao().insert(PlayerEntity("9F8E7D6C-5B4A-4392-8180-706F5E4D3C2B", "Weg", "[]", "", 0.0))
        RoomBackupStore(a).restore(BackupCodec.decode(iosFile()), replacing = true)
        assertNull(a.playerDao().byId("9F8E7D6C-5B4A-4392-8180-706F5E4D3C2B"))
        assertEquals(1, a.playerDao().all().size)
        assertEquals(2, MatchStore(a.matchDao()).all().size)
    }
}
