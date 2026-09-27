package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.squashanalyzer.android.data.AppDatabase
import com.squashanalyzer.android.data.BadgeAwardStore
import com.squashanalyzer.android.data.PlayerEntity
import com.squashanalyzer.android.data.RefereeMatchStore
import com.squashanalyzer.android.data.RoomRefereeMatchStore
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID as JavaUUID

/** "Kies speler" is what lets a match ever earn a badge (see ARCHITECTURE.md). */
@RunWith(AndroidJUnit4::class)
class MatchSetupTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private lateinit var db: AppDatabase
    private val playerId = JavaUUID.randomUUID().toString().uppercase()

    @Before fun seed() = runBlocking {
        db = AppDatabase.get(ApplicationProvider.getApplicationContext())
        db.refereeMatchDao().deleteAll()
        db.playerDao().insert(PlayerEntity(id = playerId, name = "Kies-speler-test", coachingFocusAreas = "[]", coachingNotes = "", createdAt = 0.0))
    }
    @After fun clean() = runBlocking {
        db.refereeMatchDao().deleteAll()
        db.playerDao().delete(playerId)
    }

    private fun awaitText(text: String) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test fun pickingAPlayerLinksTheNewMatchToTheirId() {
        compose.onNodeWithContentDescription("Scheidsrechter").performClick()
        awaitText("Nieuwe scheidsrechterwedstrijd")
        compose.onAllNodesWithText("Kies speler").onFirst().performClick()
        awaitText("Kies-speler-test")
        compose.onNodeWithText("Kies-speler-test").performClick()
        compose.onNodeWithText("Start").performClick()
        awaitText("SCHEIDSRECHTER")

        val store = RoomRefereeMatchStore(RefereeMatchStore(db.refereeMatchDao()), BadgeAwardStore(db.badgeAwardDao()))
        val restored = runBlocking { store.loadInProgress()!! }
        assertEquals("Kies-speler-test", restored.player1Name)
        assertEquals(playerId, restored.player1Id?.uuidString)
    }
}
