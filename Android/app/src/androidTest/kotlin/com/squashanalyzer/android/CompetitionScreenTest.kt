package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import android.content.Context
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import skip.foundation.URL
import squash.analyzer.core.TeamMatchFile

/**
 * Competitie end to end: a new team match, E1 filled in as won 3-0 (only
 * who won each game), saved; the team match then stands 3-0 in games.
 */
@RunWith(AndroidJUnit4::class)
class CompetitionScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private val home = "Testteam Compose"

    @After fun clean() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val directory = URL(fileURLWithPath = context.filesDir.absolutePath, isDirectory = true)
        val kept = TeamMatchFile.read(directory).toList().filter { it.home != home }
        TeamMatchFile.write(skip.lib.Array(kept), directory)
    }

    private fun awaitText(text: String, substring: Boolean = false) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text, substring = substring).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test fun fillingInE1GivesThreeGames() {
        compose.onNodeWithContentDescription("Competitie").performClick()
        awaitText("Nieuwe teamwedstrijd")
        compose.onNodeWithText("Nieuwe teamwedstrijd").performClick()
        awaitText("Ons team")
        compose.onNodeWithText("Ons team").performTextInput(home)
        compose.onNodeWithText("Tegenstander").performTextInput("Tegenstanders")
        compose.onNodeWithText("Maak teamwedstrijd").performClick()

        compose.waitUntil(10_000) { compose.onAllNodesWithContentDescription("Partij E1").fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithContentDescription("Partij E1").performClick()
        awaitText("Wij wonnen")
        repeat(3) { compose.onNodeWithText("Wij wonnen").performClick() }
        awaitText("Partij beslist.")
        compose.onNodeWithText("Bewaar").performClick()

        // Back on the team match: 3 games for us, E1 decided
        awaitText("3-0")
        val saved = TeamMatchFile.read(URL(fileURLWithPath = ApplicationProvider.getApplicationContext<Context>().filesDir.absolutePath, isDirectory = true))
            .toList().single { it.home == home }
        val e1 = saved.partijen.toList().first()
        assertEquals(3, e1.games.toList().count { it.ownWon })
    }

    private fun assertEquals(expected: Int, actual: Int) = org.junit.Assert.assertEquals(expected.toLong(), actual.toLong())
}
