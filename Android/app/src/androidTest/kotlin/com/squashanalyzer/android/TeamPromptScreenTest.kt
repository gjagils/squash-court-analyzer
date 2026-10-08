package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.espresso.Espresso.pressBack
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import skip.foundation.UserDefaults

/**
 * The Mijn team prompt on the home screen while no team link is saved: it
 * leads to Instellingen (with the "Waar vind ik mijn teamlink?" help link) and
 * the cross keeps it away for good. Nothing is fetched from sbn.toernooi.nl:
 * the test never saves a link.
 */
@RunWith(AndroidJUnit4::class)
class TeamPromptScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private val prompt = "Speel je competitie bij SBN?"

    private fun hasText(text: String, substring: Boolean = false) =
        compose.onAllNodesWithText(text, substring = substring).fetchSemanticsNodes().isNotEmpty()

    private fun awaitText(text: String, substring: Boolean = false) {
        compose.waitUntil(10_000) { hasText(text, substring) }
    }

    /** No link and an open prompt, as on a fresh install */
    @Before fun freshInstall() {
        UserDefaults.standard.removeObject(forKey = "sbnTeamURL")
        UserDefaults.standard.removeObject(forKey = "teamPromptDismissed")
        compose.activityRule.scenario.recreate()
    }

    @Test fun promptLeadsToSettingsWithTheHelpLink() {
        awaitText(prompt)
        compose.onNodeWithText("Waar vind ik die?").assertIsDisplayed()
        compose.onNodeWithText("Teamlink invullen").performClick()
        awaitText("Vul de openbare teamlink", substring = true)
        compose.onNodeWithText("Waar vind ik mijn teamlink?").performScrollTo().assertIsDisplayed()
        pressBack()
        awaitText(prompt)
    }

    @Test fun theCrossKeepsThePromptAway() {
        awaitText(prompt)
        compose.onNodeWithText("Sluiten").performClick()
        compose.waitUntil(10_000) { !hasText(prompt) }
        compose.activityRule.scenario.recreate()
        compose.waitForIdle()
        compose.onNodeWithContentDescription("Instellingen").assertIsDisplayed()
        compose.onAllNodesWithText(prompt).assertCountEquals(0)
    }
}
