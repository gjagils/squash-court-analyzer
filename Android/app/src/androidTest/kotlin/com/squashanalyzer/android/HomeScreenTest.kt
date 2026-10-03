package com.squashanalyzer.android

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.espresso.Espresso.pressBack
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Exercises the actual Swift-transpiled screen inside the Android host. */
@RunWith(AndroidJUnit4::class)
class HomeScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    private fun openSettingsAndReturn() {
        compose.onNodeWithContentDescription("Instellingen").assertIsDisplayed().performClick()
        compose.waitUntil(10_000) { compose.onAllNodesWithText("Mijn team").fetchSemanticsNodes().isNotEmpty() }
        pressBack()
        compose.onNodeWithText("SquashAnalyzer").assertIsDisplayed()
    }

    @Test fun everyDestinationOpensAScreenAndReturnsHome() {
        // Coach, Scheidsrechter, Badges, Afgeronde wedstrijden and Spelers
        // have dedicated tests; the gear now opens Instellingen (Mijn team).
        openSettingsAndReturn()
    }

    @Test fun homeSurvivesActivityRecreation() {
        compose.activityRule.scenario.recreate()
        openSettingsAndReturn()
        compose.onNodeWithContentDescription("Spelers").assertIsDisplayed()
    }
}
