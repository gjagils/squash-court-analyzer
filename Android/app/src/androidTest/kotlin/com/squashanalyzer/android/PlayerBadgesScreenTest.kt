package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.espresso.Espresso.pressBack
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
}
