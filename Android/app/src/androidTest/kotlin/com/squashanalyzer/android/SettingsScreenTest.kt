package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Instellingen → Mijn team: a wrong link is refused with the reason, a right
 * one is saved and can be removed again. The link is removed before going back
 * home, so the test never fetches anything from sbn.toernooi.nl. Every control
 * is scrolled to first: the Handleiding card sits above Mijn team.
 */
@RunWith(AndroidJUnit4::class)
class SettingsScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    private fun awaitText(text: String) {
        compose.waitUntil(10_000) { compose.onAllNodesWithText(text, substring = true).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test fun teamLinkIsCheckedSavedAndRemoved() {
        compose.onNodeWithContentDescription("Instellingen").performClick()
        awaitText("Vul de openbare teamlink")
        val field = compose.onNodeWithContentDescription("Teamlink")

        field.performScrollTo().performTextReplacement("https://example.com/team/1")
        compose.onNodeWithText("Bewaar teamlink").performScrollTo().performClick()
        awaitText("Gebruik een HTTPS-teamlink van sbn.toernooi.nl")

        field.performScrollTo().performTextReplacement("https://sbn.toernooi.nl/league/0a3c7e1d-2b44-4f10-9c3a-5d6e7f8091a2/team/113")
        compose.onNodeWithText("Bewaar teamlink").performScrollTo().performClick()
        awaitText("Teamlink opgeslagen")

        compose.onNodeWithText("Verwijder").performScrollTo().performClick()
        awaitText("Teamlink verwijderd")
    }
}
