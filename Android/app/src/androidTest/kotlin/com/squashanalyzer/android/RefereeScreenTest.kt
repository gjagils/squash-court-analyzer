package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.squashanalyzer.android.data.AppDatabase
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RefereeScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private lateinit var db: AppDatabase

    // Referee matches now persist, so a leftover in-progress match from a
    // previous run would show the resume chooser instead of a fresh match.
    @Before fun clean() = runBlocking {
        db = AppDatabase.get(ApplicationProvider.getApplicationContext())
        db.refereeMatchDao().deleteAll()
    }
    @After fun cleanUp() = runBlocking { db.refereeMatchDao().deleteAll() }

    private fun awaitText(text: String) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test fun refereeScoresUndoAndReturnsHome() {
        compose.onNodeWithContentDescription("Scheidsrechter").performClick()
        awaitText("Nieuwe scheidsrechterwedstrijd")
        compose.onNodeWithText("Start").performScrollTo().performClick()
        awaitText("SCHEIDSRECHTER")
        compose.onNodeWithContentDescription("Punt voor Speler 1").performClick()
        compose.onAllNodesWithText("1").fetchSemanticsNodes().isNotEmpty()
        compose.onNodeWithText("Undo").performClick()
        compose.onAllNodesWithText("LET CALL").onFirst().performClick()
        awaitText("LET")
        compose.onNodeWithText("Sluiten").performClick()
        awaitText("SQUASH ANALYZER")
    }
}
