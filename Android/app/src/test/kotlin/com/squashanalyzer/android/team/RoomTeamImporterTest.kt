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
import squash.analyzer.core.AppLanguage
import squash.analyzer.core.AppLanguageOverride
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import squash.analyzer.core.TeamImportError
import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** The team zip import on Android (now only the sample players): same rules as iOS' TeamImportService (photos: TeamPhotoImportTest on a device) */
@RunWith(RobolectricTestRunner::class)
class RoomTeamImporterTest {
    // The assertions are in Dutch; Core's texts follow the device language
    @Before fun dutchTexts() { AppLanguageOverride.shared.language = AppLanguage.dutch }
    @After fun deviceLanguage() { AppLanguageOverride.shared.language = null }

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

    @Test fun aZipAddsPlayersFromAWrappedFolder() = runTest {
        val json = """{"team":"All Inn","players":[
            {"name":"Gerd-Jan","focus":["backhand","Conditie"],"notes":"Linkshandig"},
            {"name":"Paul"}]}"""
        val result = RoomTeamImporter(db).importZip(zip("team/team.json" to json.toByteArray()))

        assertEquals("All Inn · 2 nieuw · 0 bijgewerkt · 0 foto's", result.summary)
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

    @Test fun samplePlayersNeverChangeAnExistingPlayerWithTheSameName() = runTest {
        db.playerDao().insert(PlayerEntity("A1", "wim", "[\"Drop\"]", "echt", 1.0))
        val json = """{"players":[{"name":"Bob"},{"name":"Wim"}]}"""
        val result = RoomTeamImporter(db).importZip(zip("team.json" to json.toByteArray()), addOnly = true)
        assertEquals(1, result.added)
        assertEquals(0, result.updated)
        val players = db.playerDao().all().sortedBy { it.name }
        assertEquals(listOf("Bob", "wim"), players.map { it.name })
        assertEquals("echt", players[1].coachingNotes)
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
}
