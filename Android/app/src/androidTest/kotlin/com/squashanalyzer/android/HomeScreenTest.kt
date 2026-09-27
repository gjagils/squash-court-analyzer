package com.squashanalyzer.android

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Exercises the actual Swift-transpiled screen inside the Android host. */
@RunWith(AndroidJUnit4::class)
class HomeScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    @Test fun allDestinationsExplainAvailabilityAndReturnHome() {
        // "Coach" and "Scheidsrechter" now open real screens covered by
        // dedicated tests; the rest are still placeholders.
        for (label in listOf("Afgeronde wedstrijden", "Instellingen")) {
            compose.onNodeWithContentDescription(label).assertIsDisplayed().performClick()
            compose.onNodeWithText("Deze functie is nog niet beschikbaar op Android. We voegen de onderdelen stap voor stap toe.").assertIsDisplayed()
            compose.onNodeWithText("Begrepen").performClick()
            compose.onNodeWithText("SQUASH ANALYZER").assertIsDisplayed()
        }
    }

    @Test fun homeSurvivesActivityRecreation() {
        compose.activityRule.scenario.recreate()
        compose.onNodeWithContentDescription("Afgeronde wedstrijden").assertIsDisplayed().performClick()
        compose.onNodeWithText("Begrepen").assertIsDisplayed().performClick()
        compose.onNodeWithContentDescription("Spelers").assertIsDisplayed()
    }
}
