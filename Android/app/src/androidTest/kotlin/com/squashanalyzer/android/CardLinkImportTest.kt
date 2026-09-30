package com.squashanalyzer.android

import android.content.Intent
import android.net.Uri
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createEmptyComposeRule
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.squashanalyzer.android.data.AppDatabase
import com.squashanalyzer.android.data.PlayerEntity
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import skip.foundation.Date
import skip.foundation.UUID
import skip.lib.Array as SwiftArray
import squash.analyzer.core.AwardValue
import squash.analyzer.core.BadgeKind
import squash.analyzer.core.CardSnapshot

/** Opening a card link starts the import screen; "Nieuwe speler" adds the player with the card's badges. */
@RunWith(AndroidJUnit4::class)
class CardLinkImportTest {
    @get:Rule val compose = createEmptyComposeRule()
    private val card = UUID()
    private val name = "Kaart-test-${card.uuidString.take(6)}"
    private val db = AppDatabase.get(ApplicationProvider.getApplicationContext())

    @After fun clean() = runBlocking {
        db.playerDao().all().filter { it.name == name }.forEach { db.playerDao().delete(it.id) }
        db.badgeAwardDao().deleteByIds(db.badgeAwardDao().forCard(card.uuidString).map { it.id })
    }

    private fun awaitText(text: String) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test fun openingACardLinkImportsItAsANewPlayer() {
        val award = AwardValue(cardId = card, badge = BadgeKind.fiveInARow, matchId = UUID(),
            earnedAt = Date(timeIntervalSince1970 = 1_790_000_000.0), opponentName = "Jaïr", awardedBy = "iphone", deletedAt = null)
        val link = CardSnapshot(cardId = card, name = name, awards = SwiftArray(listOf(award))).webURL().absoluteString
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(link)).setClass(ApplicationProvider.getApplicationContext(), MainActivity::class.java)

        ActivityScenario.launch<MainActivity>(intent).use {
            awaitText("Spelerskaart")
            awaitText("1 badge op de kaart · 1 nieuw voor jou")
            compose.onNodeWithText("Nieuwe speler $name").performClick()
            compose.waitUntil(10_000) { compose.onAllNodesWithText("Spelerskaart").fetchSemanticsNodes().isEmpty() }

            compose.onNodeWithContentDescription("Spelers").performClick()
            awaitText(name)
            compose.onNodeWithContentDescription("1 badges van $name").assertIsDisplayed()
        }
    }

    @Test fun aLinkOpenedOnTheSpelersScreenUpdatesItsBadgeCount() {
        // A player whose card is their own id: the link updates them
        runBlocking { db.playerDao().insert(PlayerEntity(card.uuidString, name, "[]", "", 0.0)) }
        val award = AwardValue(cardId = card, badge = BadgeKind.elevenNil, matchId = UUID(),
            earnedAt = Date(timeIntervalSince1970 = 1_790_000_000.0), opponentName = "Jaïr", awardedBy = "iphone", deletedAt = null)
        val link = CardSnapshot(cardId = card, name = name, awards = SwiftArray(listOf(award))).webURL().absoluteString
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()

        ActivityScenario.launch(MainActivity::class.java).use {
            compose.onNodeWithContentDescription("Spelers").performClick()
            awaitText(name)
            // singleTask: the running activity gets the link through onNewIntent
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(link)).setClass(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            awaitText("Bijwerken bij $name")
            compose.onNodeWithText("Bijwerken bij $name").performClick()
            compose.waitUntil(10_000) { compose.onAllNodesWithContentDescription("1 badges van $name").fetchSemanticsNodes().isNotEmpty() }
        }
    }
}
