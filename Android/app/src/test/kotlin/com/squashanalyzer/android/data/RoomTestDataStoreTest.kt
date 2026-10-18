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
import skip.foundation.Date
import skip.foundation.URL
import skip.lib.Array as SwiftArray
import squash.analyzer.core.*

/** "Testgegevens opruimen": the same matches as iOS' `SwiftDataTestDataStore`, through Core's `TestDataCleanup` */
@RunWith(RobolectricTestRunner::class)
class RoomTestDataStoreTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private lateinit var db: AppDatabase
    private lateinit var coach: RoomCoachMatchStore
    private lateinit var matchStore: MatchStore
    private lateinit var teamStore: BackgroundTeamMatchStore
    private lateinit var store: RoomTestDataStore

    @Before fun open() {
        db = Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java).allowMainThreadQueries().build()
        matchStore = MatchStore(db.matchDao())
        val refereeStore = RefereeMatchStore(db.refereeMatchDao())
        val badges = BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), matchStore, refereeStore, "test-install")
        coach = RoomCoachMatchStore(matchStore, badges)
        val dir = java.nio.file.Files.createTempDirectory("test-data")
        teamStore = BackgroundTeamMatchStore(directory = URL(fileURLWithPath = dir.toString(), isDirectory = true))
        store = RoomTestDataStore(matchStore, refereeStore, badges, teamStore,
            RoomBackupStore(db, URL(fileURLWithPath = dir.toString(), isDirectory = true)), "test", dir.resolve("Voor opruimen").toFile())
    }

    @After fun close() { db.close() }

    private suspend fun coachMatch(opponent: String, finish: Boolean): Match {
        val match = Match()
        match.setupMatch(player1 = "Gerd-Jan", player2 = opponent, startingServer = Player.player1)
        repeat(3) {
            match.currentGame.selectPlayer(Player.player1)
            match.currentGame.selectPointType(PointType.winner)
            match.currentGame.selectZone(CourtZone.frontLeft)
            match.currentGame.addPoint(shotType = ShotType.drive)
        }
        // Finished by filling in the result (best of 5), as in RoomMatchHistoryStoreTest
        if (finish) assertTrue(match.completeResult(with = SwiftArray(listOf(Player.player1, Player.player1, Player.player1))))
        coach.save(match)
        return match
    }

    @Test fun countsAndRemovesOnlyTheChosenGroups() = runTest {
        coachMatch("Whiskey", finish = true)
        coachMatch("Paul", finish = false)
        val kept = coachMatch("Paul", finish = true)
        teamStore.save(TeamMatch(date = Date(), home = "Bombardinos", away = "Squash Delft 8", ownSide = TeamSide.home))
        val before = Date(timeIntervalSince1970 = Date().timeIntervalSince1970 + 3_600)

        assertEquals(TestDataCounts(samplePlayers = 1, unfinished = 1, competition = 1), store.counts(before = before))

        store.remove(SwiftArray(listOf(TestDataGroup.samplePlayers, TestDataGroup.unfinished)), before = before)
        assertEquals(listOf(kept.id.uuidString), matchStore.all().map { it.id })
        assertEquals("competition was not chosen", 1, teamStore.loadAll().count)

        // Nothing from after the start goes
        assertTrue(store.counts(before = Date(timeIntervalSince1970 = 0.0)).isEmpty)
    }

    @Test fun theBackupIsAFullBackupFile() = runTest {
        coachMatch("Whiskey", finish = true)
        val dir = java.nio.file.Files.createTempDirectory("backup").toFile()
        val backups = RoomTestDataStore(matchStore, RefereeMatchStore(db.refereeMatchDao()),
            BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), matchStore, RefereeMatchStore(db.refereeMatchDao()), "test-install"),
            teamStore, RoomBackupStore(db, URL(fileURLWithPath = dir.toString(), isDirectory = true)), "test", java.io.File(dir, "Voor opruimen"))
        backups.backUp()
        val file = java.io.File(dir, "Voor opruimen").listFiles()!!.single()
        val backup = BackupCodec.decode(skip.foundation.Data(platformValue = file.readBytes()))
        assertEquals(1, backup.matches.count)
    }
}
