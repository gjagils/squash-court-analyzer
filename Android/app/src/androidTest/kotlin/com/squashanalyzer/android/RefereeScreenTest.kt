package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RefereeScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    private fun awaitText(text: String) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test fun refereeScoresUndoAndReturnsHome() {
        compose.onNodeWithContentDescription("Scheidsrechter").performClick()
        awaitText("SCHEIDSRECHTER")
        compose.onNodeWithContentDescription("Punt voor Speler 1").performClick()
        compose.onAllNodesWithText("1").fetchSemanticsNodes().isNotEmpty()
        compose.onNodeWithText("Undo").performClick()
        compose.onAllNodesWithText("LET").onFirst().performClick()
        awaitText("LET")
        compose.onNodeWithText("Sluiten").performClick()
        awaitText("SQUASH ANALYZER")
    }
}
