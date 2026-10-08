package com.squashanalyzer.android

import android.content.Context
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.text.TextLayoutResult
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import skip.foundation.URL
import squash.analyzer.core.TeamMatchFile

/**
 * The header of a team match: the three labels under the score each stay on
 * one line (COMPETITIEPUNTEN used to break as "COMPETITIEPUNTE" + "N").
 */
@RunWith(AndroidJUnit4::class)
class TeamMatchHeaderTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private val home = "Testteam Kop"

    @After fun clean() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val directory = URL(fileURLWithPath = context.filesDir.absolutePath, isDirectory = true)
        val kept = TeamMatchFile.read(directory).toList().filter { it.home != home }
        TeamMatchFile.write(skip.lib.Array(kept), directory)
    }

    private fun awaitText(text: String) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() }
    }

    private fun lineCount(text: String): Int {
        // PARTIJEN is also the heading of the list below: the first one is the stat under the score
        val node = compose.onAllNodesWithText(text)[0].fetchSemanticsNode()
        val results = mutableListOf<TextLayoutResult>()
        node.config[SemanticsActions.GetTextLayoutResult].action?.invoke(results)
        return results.first().lineCount
    }

    @Test fun theStatLabelsStayOnOneLine() {
        compose.onNodeWithContentDescription("Competitie").performClick()
        awaitText("Nieuwe teamwedstrijd")
        compose.onNodeWithText("Nieuwe teamwedstrijd").performClick()
        awaitText("Ons team")
        compose.onNodeWithText("Ons team").performTextInput(home)
        compose.onNodeWithText("Tegenstander").performTextInput("Tegenstanders")
        compose.onNodeWithText("Maak teamwedstrijd").performClick()
        awaitText("COMPETITIEPUNTEN")
        for (label in listOf("PARTIJEN", "COMPETITIEPUNTEN", "RALLYPUNTEN")) {
            assertEquals("$label on one line", 1, lineCount(label))
        }
    }
}
