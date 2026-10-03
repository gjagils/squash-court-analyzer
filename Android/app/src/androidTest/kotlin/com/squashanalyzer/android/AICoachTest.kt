package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.squashanalyzer.android.aicoach.KeystoreAPIKeyStore
import com.squashanalyzer.android.data.AppDatabase
import com.squashanalyzer.android.data.BadgeAwardStore
import com.squashanalyzer.android.data.MatchStore
import com.squashanalyzer.android.data.RefereeMatchStore
import com.squashanalyzer.android.data.RoomCoachMatchStore
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import squash.analyzer.core.*

/**
 * The OpenAI key in the Android Keystore, the key in Instellingen, and the
 * game analysis after a finished coach game. Never calls OpenAI.
 */
@RunWith(AndroidJUnit4::class)
class AICoachTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private lateinit var db: AppDatabase
    private lateinit var store: RoomCoachMatchStore
    private var seeded: Match? = null

    @Before fun before() = runBlocking {
        KeystoreAPIKeyStore(context).openAIAPIKey = null
        db = AppDatabase.get(context)
        store = RoomCoachMatchStore(MatchStore(db.matchDao()), BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "test-install"))
    }

    @After fun after() = runBlocking {
        KeystoreAPIKeyStore(context).openAIAPIKey = null
        seeded?.let { db.matchDao().deleteMatchById(it.id.uuidString) }
        Unit
    }

    private fun awaitText(text: String, substring: Boolean = false) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text, substring = substring).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test fun keystoreKeepsTheKeyEncrypted() {
        val keys = KeystoreAPIKeyStore(context)
        assertNull(keys.openAIAPIKey)
        keys.openAIAPIKey = "sk-test-123"
        assertEquals("sk-test-123", KeystoreAPIKeyStore(context).openAIAPIKey)
        val stored = context.getSharedPreferences(KeystoreAPIKeyStore.PREFS, android.content.Context.MODE_PRIVATE).all.values.joinToString()
        assertFalse(stored.contains("sk-test-123"))
        keys.openAIAPIKey = null
        assertNull(KeystoreAPIKeyStore(context).openAIAPIKey)
    }

    @Test fun keyIsSavedAndRemovedInSettings() {
        compose.onNodeWithContentDescription("Instellingen").performClick()
        awaitText("Geen API key ingesteld")
        // The AI Coach section is below the fold: scroll to each control first
        compose.onNodeWithContentDescription("OpenAI API key").performScrollTo().performTextReplacement("sk-test-456")
        compose.onNodeWithText("Bewaar API key").performScrollTo().performClick()
        awaitText("API key opgeslagen")
        assertEquals("sk-test-456", KeystoreAPIKeyStore(context).openAIAPIKey)
        compose.onNodeWithText("Verwijder key").performScrollTo().performClick()
        awaitText("API key verwijderd")
        assertNull(KeystoreAPIKeyStore(context).openAIAPIKey)
    }

    @Test fun finishedGameOpensTheAnalysisWithTheSharedAdvice() {
        val match = Match()
        match.setupMatch(player1 = "AnalyseTest", player2 = "Tegenstander", startingServer = Player.player1)
        repeat(10) { match.currentGame.addPoint(to = Player.player1, pointType = PointType.winner, at = CourtZone.frontLeft, with = ShotType.drive) }
        seeded = match
        runBlocking { store.save(match) }

        compose.onNodeWithContentDescription("Coach").performClick()
        awaitText("Hervatten")
        compose.onNodeWithText("Hervatten").performClick()
        compose.onNodeWithContentDescription("Punt voor AnalyseTest").performClick()
        awaitText("Hoe werd het punt gewonnen?")
        compose.onNodeWithText("SERVICEPUNT").performClick()
        awaitText("ANALYSE")
        compose.onNodeWithText("ANALYSE").performClick()

        awaitText("Coach dashboard")
        awaitText("Voorin werkt je drive het best (10 punten).")
        awaitText("Waar vallen de punten")
        // Without an OpenAI key there is no AI card, only the local advice
        assertTrue(compose.onAllNodesWithText("Stel je API key in bij Instellingen").fetchSemanticsNodes().isEmpty())
        compose.onAllNodesWithContentDescription("Sluiten").onLast().performClick()
        awaitText("VOLGENDE GAME")
    }
}
