package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.squashanalyzer.android.data.AppDatabase
import com.squashanalyzer.android.data.BadgeAwardStore
import com.squashanalyzer.android.data.MatchStatus
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

/** Coach on Android like iOS: Let call, and Stop with incompleet or niet opslaan */
@RunWith(AndroidJUnit4::class)
class CoachStopTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private lateinit var db: AppDatabase
    private lateinit var store: RoomCoachMatchStore
    private lateinit var seeded: Match

    @Before fun seed() = runBlocking {
        db = AppDatabase.get(ApplicationProvider.getApplicationContext())
        store = RoomCoachMatchStore(MatchStore(db.matchDao()), BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "test-install"))
        seeded = Match()
        seeded.setupMatch(player1 = "StopTest", player2 = "Tegenstander", startingServer = Player.player1)
        seeded.currentGame.addPoint(to = Player.player1, pointType = PointType.winner, at = CourtZone.frontLeft, with = ShotType.drop)
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

    private fun stop(choice: String) {
        compose.waitUntil(10_000) { compose.onAllNodes(hasText("Stop") and isEnabled()).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("Stop").performClick()
        awaitText(choice)
        compose.onNodeWithText(choice).performClick()
        awaitText("SQUASH ANALYZER")
    }

    @Test fun letCallIsSavedAndIncompleteIsKept() {
        resume()
        awaitText("StopTest: Winner · Drop · Voor Links")
        compose.onNodeWithText("LET CALL").performClick()
        awaitText("Wie vraagt de let?")
        compose.onAllNodesWithText("Tegenstander").onLast().performClick()
        compose.waitUntil(10_000) { runBlocking { store.loadInProgress()?.currentGame?.lets?.count == 1 } }
        stop("Opslaan als incompleet")
        val saved = runBlocking { MatchStore(db.matchDao()).all().single { it.id == seeded.id.uuidString } }
        assertEquals(MatchStatus.ABANDONED, saved.status)
        assertEquals(1, saved.games.single().lets.size)
    }

    @Test fun nietOpslaanRemovesTheMatch() {
        resume()
        stop("Niet opslaan")
        compose.waitUntil(10_000) {
            runBlocking { MatchStore(db.matchDao()).all().none { it.id == seeded.id.uuidString } }
        }
    }
}
