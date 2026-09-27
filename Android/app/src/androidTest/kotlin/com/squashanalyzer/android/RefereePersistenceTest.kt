package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.squashanalyzer.android.data.AppDatabase
import com.squashanalyzer.android.data.BadgeAwardStore
import com.squashanalyzer.android.data.RefereeMatchStore
import com.squashanalyzer.android.data.RoomRefereeMatchStore
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import squash.analyzer.core.*

@RunWith(AndroidJUnit4::class)
class RefereePersistenceTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private lateinit var db: AppDatabase
    private lateinit var store: RoomRefereeMatchStore
    private lateinit var seeded: RefereeMatch

    @Before fun seed() = runBlocking {
        db = AppDatabase.get(ApplicationProvider.getApplicationContext())
        db.refereeMatchDao().deleteAll()
        store = RoomRefereeMatchStore(RefereeMatchStore(db.refereeMatchDao()), BadgeAwardStore(db.badgeAwardDao()))
        seeded = RefereeMatch(player1Name = "RefTest", player2Name = "Tegenstander", bestOf = 5, startingServer = Player.player1)
        store.save(seeded)
    }
    @After fun clean() = runBlocking { db.refereeMatchDao().deleteAll() }

    private fun awaitText(text: String) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() }
    }
    private fun resume() {
        compose.onNodeWithContentDescription("Scheidsrechter").performClick()
        awaitText("Hervatten")
        compose.onNodeWithText("Hervatten").performClick()
        awaitText("SCHEIDSRECHTER")
    }
    private fun closeSaved() {
        compose.onNodeWithText("Sluiten").performClick()
        awaitText("SQUASH ANALYZER")
    }

    @Test fun pointIsSavedAndResumedAfterActivityRestart() {
        resume()
        compose.onNodeWithContentDescription("Punt voor RefTest").performClick()
        compose.waitUntil(10_000) {
            runBlocking { store.loadInProgress()?.player1Score == 1 }
        }
        closeSaved()
        compose.activityRule.scenario.recreate()
        resume()
        assertEquals(1, runBlocking { store.loadInProgress()!!.player1Score })
        closeSaved()
        assertEquals(seeded.id, runBlocking { store.loadInProgress()!!.id })
    }

    // Undo pops a private, in-memory stack (see RefereeMatch.undo()) that is
    // not itself persisted, so it only reaches points scored in the live
    // session — verified here without an activity restart in between.
    @Test fun undoWithinTheLiveSessionIsPersisted() {
        resume()
        compose.onNodeWithContentDescription("Punt voor RefTest").performClick()
        compose.waitUntil(10_000) {
            runBlocking { store.loadInProgress()?.player1Score == 1 }
        }
        compose.onNodeWithText("Undo").performClick()
        compose.waitUntil(10_000) {
            runBlocking { store.loadInProgress()?.player1Score == 0 }
        }
        closeSaved()
        assertEquals(0, runBlocking { store.loadInProgress()!!.player1Score })
    }
}
