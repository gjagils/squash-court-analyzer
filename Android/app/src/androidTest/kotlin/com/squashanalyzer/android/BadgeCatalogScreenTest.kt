package com.squashanalyzer.android

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.espresso.Espresso.pressBack
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** The badge catalog needs no player or match data, so it's reachable from a clean install. */
@RunWith(AndroidJUnit4::class)
class BadgeCatalogScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    @Test fun catalogListsBadgesAndReturnsHome() {
        compose.onNodeWithContentDescription("Badges").assertIsDisplayed().performClick()
        compose.onNodeWithText("Alle badges").assertIsDisplayed()
        compose.onNodeWithText("5 points in a row").assertIsDisplayed()
        pressBack()
        compose.onNodeWithText("SQUASH ANALYZER").assertIsDisplayed()
    }
}
