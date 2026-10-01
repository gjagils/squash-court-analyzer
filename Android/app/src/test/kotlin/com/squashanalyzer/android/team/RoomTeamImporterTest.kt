package com.squashanalyzer.android.team

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.squashanalyzer.android.data.AppDatabase
import com.squashanalyzer.android.data.PlayerEntity
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import skip.foundation.Data
import skip.foundation.URL
import squash.analyzer.core.TeamDownloader
import squash.analyzer.core.TeamImportError
import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** Spelers → Team via link on Android: same rules as iOS' TeamImportService (photos: TeamPhotoImportTest on a device) */
@RunWith(RobolectricTestRunner::class)
class RoomTeamImporterTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private lateinit var db: AppDatabase

    @Before fun open() {
        db = Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java).allowMainThreadQueries().build()
    }

    @After fun close() {
        db.close()
    }

    private fun zip(vararg files: Pair<String, ByteArray>): ByteArray {
        val out = ByteArrayOutputStream()
        ZipOutputStream(out).use { zip ->
            for ((path, bytes) in files) {
                zip.putNextEntry(ZipEntry(path))
                zip.write(bytes)
                zip.closeEntry()
            }
        }
        return out.toByteArray()
    }

    private class Fake(val bytes: ByteArray) : TeamDownloader {
        var asked: String? = null
        override suspend fun download(url: URL): Data {
            asked = url.absoluteString
            return Data(platformValue = bytes)
        }
    }

    @Test fun aLinkAddsPlayersFromAWrappedFolder() = runTest {
        val json = """{"team":"All Inn","players":[
            {"name":"Gerd-Jan","focus":["backhand","Conditie"],"notes":"Linkshandig"},
            {"name":"Paul"}]}"""
        val fake = Fake(zip("team/team.json" to json.toByteArray()))
        val result = RoomTeamImporter(db, fake).importTeam(" https://squashanalyzer.com/teams/k7f3/team.zip ")

        assertEquals("All Inn · 2 nieuw · 0 bijgewerkt · 0 foto's", result.summary)
        assertEquals("https://squashanalyzer.com/teams/k7f3/team.zip", fake.asked)
        val players = db.playerDao().all()
        assertEquals(listOf("Gerd-Jan", "Paul"), players.map { it.name })
        assertEquals("[\"Backhand\",\"Conditie\"]", players[0].coachingFocusAreas)
        assertEquals("Linkshandig", players[0].coachingNotes)
    }

    @Test fun anExistingPlayerIsUpdatedByNameAndKeepsWhatTheTeamLeavesOut() = runTest {
        db.playerDao().insert(PlayerEntity("A1", "paul", "[\"Drop\"]", "oud", 1.0))
        val result = RoomTeamImporter(db).importZip(zip("team.json" to """{"players":[{"name":"Paul"}]}""".toByteArray()))
        assertEquals(1, result.updated)
        val paul = db.playerDao().all().single()
        assertEquals("paul", paul.name)
        assertEquals("[\"Drop\"]", paul.coachingFocusAreas)
        assertEquals("oud", paul.coachingNotes)
    }

    @Test fun aBadTeamWritesNothing() = runTest {
        val missingPhoto = zip("team.json" to """{"players":[{"name":"A"},{"name":"B","photo":"nope.jpg"}]}""".toByteArray())
        try {
            RoomTeamImporter(db).importZip(missingPhoto)
            fail("a missing photo must stop the import")
        } catch (error: TeamImportError) {
            assertTrue(error.message.contains("nope.jpg"))
        }
        assertTrue(db.playerDao().all().isEmpty())
    }

    @Test fun onlySquashAnalyzerTeamLinksAreDownloaded() = runTest {
        val fake = Fake(ByteArray(0))
        try {
            RoomTeamImporter(db, fake).importTeam("https://example.com/teams/x/team.zip")
            fail("other sites are refused")
        } catch (error: TeamImportError) {
            assertNull(fake.asked)
        }
    }
}
