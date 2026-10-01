package com.squashanalyzer.android

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.intent.Intents
import androidx.test.espresso.intent.Intents.intending
import androidx.test.espresso.intent.matcher.IntentMatchers.hasAction
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.squashanalyzer.android.data.AppDatabase
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import skip.foundation.Data
import skip.foundation.Date
import skip.lib.Array as SwiftArray
import squash.analyzer.core.*
import java.io.File

/**
 * Instellingen → Back-up with the system file pickers answered by the test:
 * "Maak back-up" writes a valid backup file, "Zet back-up terug" reads one and
 * merges it after the question.
 */
@RunWith(AndroidJUnit4::class)
class BackupScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private val saved = File(context.cacheDir, "made-by-test.json")
    private val incoming = File(context.cacheDir, "to-restore.json")
    private val playerId = "7C1D2E3F-4A5B-4C6D-8E9F-A0B1C2D3E4F5"

    @Before fun before() {
        saved.delete()
        val player = PlayerBackupData(id = playerId, name = "Terugzet-test", coachingFocusAreas = SwiftArray(), coachingNotes = "",
            createdAt = Date(timeIntervalSince1970 = 1_790_000_000.0), photoBase64 = null)
        val backup = FullBackup(version = 2, backupDate = Date(timeIntervalSince1970 = 1_790_000_000.0), players = SwiftArray(listOf(player)),
            matches = SwiftArray(), standaloneGames = SwiftArray())
        incoming.writeBytes(BackupCodec.encode(backup, appVersion = "test").platformValue)
        Intents.init()
        intending(hasAction(Intent.ACTION_CREATE_DOCUMENT)).respondWith(
            Instrumentation.ActivityResult(Activity.RESULT_OK, Intent().setData(Uri.fromFile(saved))))
        intending(hasAction(Intent.ACTION_OPEN_DOCUMENT)).respondWith(
            Instrumentation.ActivityResult(Activity.RESULT_OK, Intent().setData(Uri.fromFile(incoming))))
    }

    @After fun after() = runBlocking {
        Intents.release()
        AppDatabase.get(context).playerDao().delete(playerId)
        saved.delete()
        incoming.delete()
        Unit
    }

    private fun awaitText(text: String) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text, substring = true).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test fun backupIsWrittenAndRestored() {
        compose.onNodeWithContentDescription("Instellingen").performClick()
        awaitText("Maak back-up")

        compose.onNodeWithText("Maak back-up").performScrollTo().performClick()
        awaitText("Back-up opgeslagen")
        val written = BackupCodec.decode(Data(platformValue = saved.readBytes()))
        assertEquals(2, written.version)

        compose.onNodeWithText("Zet back-up terug").performScrollTo().performClick()
        awaitText("Back-up terugzetten?")
        compose.onNodeWithText("Samenvoegen").performClick()
        awaitText("Teruggezet: 1 spelers")
        assertEquals("Terugzet-test", runBlocking { AppDatabase.get(context).playerDao().byId(playerId)?.name })
    }
}
