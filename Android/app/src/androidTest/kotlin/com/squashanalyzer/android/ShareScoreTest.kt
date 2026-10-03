package com.squashanalyzer.android

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.intent.Intents
import androidx.test.espresso.intent.Intents.intended
import androidx.test.espresso.intent.Intents.intending
import androidx.test.espresso.intent.matcher.IntentMatchers.hasAction
import androidx.test.espresso.intent.matcher.IntentMatchers.hasExtra
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.squashanalyzer.android.data.AppDatabase
import com.squashanalyzer.android.data.BadgeAwardStore
import com.squashanalyzer.android.data.MatchStore
import com.squashanalyzer.android.data.RefereeMatchStore
import com.squashanalyzer.android.data.RoomCoachMatchStore
import kotlinx.coroutines.runBlocking
import org.hamcrest.Matchers.allOf
import org.hamcrest.Matchers.containsString
import org.hamcrest.Matchers.equalTo
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import squash.analyzer.core.*

/** "Deel score" after a coach match and "Deel" in the game analysis hand the shared texts to the share sheet */
@RunWith(AndroidJUnit4::class)
class ShareScoreTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()
    private lateinit var db: AppDatabase
    private lateinit var match: Match

    @Before fun seed() = runBlocking {
        db = AppDatabase.get(context)
        val store = RoomCoachMatchStore(MatchStore(db.matchDao()), BadgeAwardStore(db.badgeAwardDao(), db.playerDao(), MatchStore(db.matchDao()), RefereeMatchStore(db.refereeMatchDao()), "test-install"))
        match = Match()
        match.setupMatch(player1 = "DeelTest", player2 = "Tegenstander", startingServer = Player.player1)
        // Two games won, the third at 10-0: one more point ends the match
        repeat(2) {
            repeat(11) { match.currentGame.addPoint(to = Player.player1, pointType = PointType.winner, at = CourtZone.frontLeft, with = ShotType.drive) }
            match.onGameEnd()
        }
        repeat(10) { match.currentGame.addPoint(to = Player.player1, pointType = PointType.winner, at = CourtZone.backRight, with = ShotType.lob) }
        store.save(match)
        Intents.init()
        intending(hasAction(Intent.ACTION_CHOOSER)).respondWith(Instrumentation.ActivityResult(Activity.RESULT_OK, null))
    }

    @After fun clean() = runBlocking {
        Intents.release()
        db.matchDao().deleteMatchById(match.id.uuidString)
    }

    private fun awaitText(text: String) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() }
    }

    private fun sharedTextContains(text: String) {
        compose.waitUntil(10_000) { Intents.getIntents().isNotEmpty() }
        intended(allOf(hasAction(Intent.ACTION_CHOOSER), hasExtra(equalTo(Intent.EXTRA_INTENT),
            allOf(hasAction(Intent.ACTION_SEND), hasExtra(Intent.EXTRA_TEXT, containsString(text))))))
    }

    @Test fun scoreAndGameAnalysisAreShared() {
        compose.onNodeWithContentDescription("Coach").performClick()
        awaitText("Hervatten")
        compose.onNodeWithText("Hervatten").performClick()
        compose.waitUntil(10_000) { compose.onAllNodes(hasContentDescription("Punt voor DeelTest") and isEnabled()).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithContentDescription("Punt voor DeelTest").performClick()
        awaitText("Hoe werd het punt gewonnen?")
        // The point types slide in (0.2 s animation); a click during it can miss
        Thread.sleep(800)
        compose.onNodeWithText("SERVICEPUNT").performClick()
        awaitText("DEEL SCORE")

        compose.onNodeWithText("DEEL SCORE").performClick()
        awaitText("DELEN")
        compose.onNodeWithText("Scorekaart").performClick()
        awaitText("Tabel met alle games")
        compose.onNodeWithText("DELEN").performClick()
        sharedTextContains("DeelTest")
        compose.onAllNodesWithContentDescription("Sluiten").onLast().performClick()

        compose.onNodeWithText("ANALYSE").performClick()
        awaitText("Coach dashboard")
        compose.onNodeWithContentDescription("Deel game-analyse").performClick()
        sharedTextContains("SQUASH GAME ANALYSE")
    }
}
