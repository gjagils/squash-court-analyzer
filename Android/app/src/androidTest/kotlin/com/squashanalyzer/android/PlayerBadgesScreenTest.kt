package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import androidx.test.espresso.Espresso.pressBack
import androidx.test.espresso.intent.Intents
import androidx.test.espresso.intent.Intents.intended
import androidx.test.espresso.intent.Intents.intending
import androidx.test.espresso.intent.matcher.IntentMatchers.hasAction
import androidx.test.espresso.intent.matcher.IntentMatchers.hasExtra
import org.hamcrest.Matchers.allOf
import org.hamcrest.Matchers.startsWith
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.squashanalyzer.android.data.AppDatabase
import com.squashanalyzer.android.data.BadgeAwardEntity
import com.squashanalyzer.android.data.PlayerEntity
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID as JavaUUID

/** A picked player's earned badges show up in "Spelers" and on their own screen. */
@RunWith(AndroidJUnit4::class)
class PlayerBadgesScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private lateinit var db: AppDatabase
    private val playerId = JavaUUID.randomUUID().toString().uppercase()
    private val matchId = JavaUUID.randomUUID().toString().uppercase()
    private val playerName = "Badge-test-${playerId.take(6)}"

    @Before fun seed() = runBlocking {
        db = AppDatabase.get(ApplicationProvider.getApplicationContext())
        db.playerDao().insert(PlayerEntity(id = playerId, name = playerName, coachingFocusAreas = "[]", coachingNotes = "", createdAt = 0.0))
        db.badgeAwardDao().insertAll(listOf(
            BadgeAwardEntity(id = "$playerId:five-in-a-row:$matchId", cardId = playerId, badge = "five-in-a-row", matchId = matchId,
                earnedAt = 0L, opponentName = "Tegenstander", awardedBy = "test-install")
        ))
    }
    @After fun clean() = runBlocking {
        db.playerDao().delete(playerId)
        db.badgeAwardDao().deleteForMatch(matchId)
    }

    private fun awaitText(text: String) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test fun playerRowShowsBadgeCountAndOpensEarnedBadges() {
        compose.onNodeWithContentDescription("Spelers").performClick()
        awaitText(playerName)
        compose.onNodeWithContentDescription("1 badges van $playerName").assertIsDisplayed().performClick()
        awaitText("5 points in a row")
        pressBack()
        awaitText(playerName)
    }

    @Test fun deelKaartOpensTheShareSheetWithTheCardLink() {
        Intents.init()
        try {
            // Answer the share sheet straight away instead of showing it
            intending(hasAction(Intent.ACTION_CHOOSER)).respondWith(Instrumentation.ActivityResult(Activity.RESULT_OK, null))
            compose.onNodeWithContentDescription("Spelers").performClick()
            awaitText(playerName)
            compose.onNodeWithContentDescription("1 badges van $playerName").performClick()
            awaitText("5 points in a row")
            // "Deel kaart" sits under the badge grid, as on iOS: swipe down to it
            compose.onNodeWithContentDescription("Deel kaart").performScrollTo().performClick()
            compose.waitUntil(10_000) { Intents.getIntents().isNotEmpty() }
            intended(allOf(hasAction(Intent.ACTION_CHOOSER), hasExtra(org.hamcrest.Matchers.equalTo(Intent.EXTRA_INTENT),
                allOf(hasAction(Intent.ACTION_SEND), hasExtra(Intent.EXTRA_TEXT, startsWith("Badgekaart van $playerName: https://squashanalyzer.com/kaart/#"))))))
        } finally {
            Intents.release()
        }
    }
}
