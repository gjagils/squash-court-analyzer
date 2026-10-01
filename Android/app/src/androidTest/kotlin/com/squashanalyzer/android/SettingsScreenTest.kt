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
 * is scrolled to first: the Handleiding card sits above Mijn team. A click is
 * retried until its message shows: typing opens the keyboard, which moves the
 * button while the click is on its way (the old flake, about 1 run in 5).
 */
@RunWith(AndroidJUnit4::class)
class SettingsScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    private fun hasText(text: String) =
        compose.onAllNodesWithText(text, substring = true).fetchSemanticsNodes().isNotEmpty()

    private fun awaitText(text: String) {
        compose.waitUntil(10_000) { hasText(text) }
    }

    /** Scrolls to the button and clicks it until `expected` shows (saving or removing twice does no harm) */
    private fun clickUntil(button: String, expected: String) {
        repeat(3) {
            compose.waitForIdle()
            compose.onNodeWithText(button).performScrollTo().performClick()
            try {
                compose.waitUntil(3_000) { hasText(expected) }
                return
            } catch (_: androidx.compose.ui.test.ComposeTimeoutException) {
            }
        }
        awaitText(expected)
    }

    @Test fun teamLinkIsCheckedSavedAndRemoved() {
        compose.onNodeWithContentDescription("Instellingen").performClick()
        awaitText("Vul de openbare teamlink")
        val field = compose.onNodeWithContentDescription("Teamlink")

        field.performScrollTo().performTextReplacement("https://example.com/team/1")
        clickUntil("Bewaar teamlink", "Gebruik een HTTPS-teamlink van sbn.toernooi.nl")

        field.performScrollTo().performTextReplacement("https://sbn.toernooi.nl/league/0a3c7e1d-2b44-4f10-9c3a-5d6e7f8091a2/team/113")
        clickUntil("Bewaar teamlink", "Teamlink opgeslagen")

        clickUntil("Verwijder", "Teamlink verwijderd")
    }
}
