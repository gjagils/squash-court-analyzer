package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.pressBack
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
import org.junit.runner.RunWith
import squash.analyzer.core.Match
import squash.analyzer.core.Player

/** "Afgeronde wedstrijden" lists completed/abandoned matches; in-progress ones are excluded. */
@RunWith(AndroidJUnit4::class)
class MatchHistoryScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private lateinit var db: AppDatabase
    private lateinit var seeded: Match

    @Before fun seed() = runBlocking {
        db = AppDatabase.get(ApplicationProvider.getApplicationContext())
        val store = RoomCoachMatchStore(MatchStore(db.matchDao()), BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "test-install"))
        seeded = Match()
        seeded.setupMatch(player1 = "HistoryP1", player2 = "HistoryP2", startingServer = Player.player1)
        repeat(3) { game ->
            repeat(11) {
                seeded.currentGame.selectPlayer(Player.player1)
                seeded.currentGame.selectPointType(squash.analyzer.core.PointType.winner)
                seeded.currentGame.selectZone(squash.analyzer.core.CourtZone.frontLeft)
                seeded.currentGame.addPoint(shotType = squash.analyzer.core.ShotType.drive)
            }
            if (game < 2) seeded.onGameEnd()
        }
        store.save(seeded)
    }
    @After fun clean() = runBlocking { db.matchDao().deleteMatchById(seeded.id.uuidString) }

    private fun awaitText(text: String) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test fun completedMatchAppearsInHistoryAndReturnsHome() {
        compose.onNodeWithContentDescription("Afgeronde wedstrijden").performClick()
        awaitText("Afgeronde wedstrijden")
        awaitText("HistoryP1 – HistoryP2")
        pressBack()
        awaitText("SQUASH ANALYZER")
    }
}
