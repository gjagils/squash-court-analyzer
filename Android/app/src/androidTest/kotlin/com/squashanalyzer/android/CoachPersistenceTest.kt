package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.squashanalyzer.android.data.AppDatabase
import com.squashanalyzer.android.data.BadgeAwardStore
import com.squashanalyzer.android.data.MatchStore
import com.squashanalyzer.android.data.RefereeMatchStore
import com.squashanalyzer.android.data.RoomCoachMatchStore
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import squash.analyzer.core.*

@RunWith(AndroidJUnit4::class)
class CoachPersistenceTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private lateinit var db: AppDatabase
    private lateinit var store: RoomCoachMatchStore
    private lateinit var seeded: Match

    @Before fun seed() = runBlocking {
        db = AppDatabase.get(ApplicationProvider.getApplicationContext())
        store = RoomCoachMatchStore(MatchStore(db.matchDao()), BadgeAwardStore(db.badgeAwardDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao())))
        seeded = Match()
        seeded.setupMatch(player1 = "CoachTest", player2 = "Tegenstander", startingServer = Player.player1)
        store.save(seeded)
    }
    @After fun clean() = runBlocking { db.matchDao().deleteMatchById(seeded.id.uuidString) }

    private fun awaitText(text: String) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() }
    }
    private fun resume() {
        compose.onNodeWithContentDescription("Coach").performClick()
        awaitText("Hervatten")
        compose.onNodeWithText("Hervatten").performClick()
        awaitText("Tik op de score van wie scoort")
    }
    private fun closeSaved() {
        compose.waitUntil(10_000) {
            compose.onAllNodes(hasText("Bewaar & sluit") and isEnabled()).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText("Bewaar & sluit").performClick()
        awaitText("SQUASH ANALYZER")
    }

    @Test fun pointIsSavedAndResumedAfterActivityRestartAndUndoIsDurable() {
        resume()
        compose.onNodeWithContentDescription("Punt voor CoachTest").performClick()
        awaitText("Hoe werd het punt gewonnen?")
        // Service point scores directly, exercising the immediate-scoring path.
        compose.onNodeWithText("SERVICEPUNT").performClick()
        compose.waitUntil(10_000) {
            runBlocking { store.loadInProgress()?.currentGame?.player1Score == 1 }
        }
        closeSaved()
        compose.activityRule.scenario.recreate()
        resume()
        assertEquals(1, runBlocking { store.loadInProgress()!!.currentGame.player1Score })
        compose.onNodeWithText("UNDO").performClick()
        compose.waitUntil(10_000) {
            runBlocking { store.loadInProgress()?.currentGame?.player1Score == 0 }
        }
        closeSaved()
        assertEquals(seeded.id, runBlocking { store.loadInProgress()!!.id })
    }
}
