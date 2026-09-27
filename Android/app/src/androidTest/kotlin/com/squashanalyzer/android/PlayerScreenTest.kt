package com.squashanalyzer.android

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.espresso.Espresso.closeSoftKeyboard
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class PlayerScreenTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    @Test fun createEditReopenAndDeletePlayer() {
        val original = "Speler ${UUID.randomUUID().toString().take(6)}"
        val renamed = "$original nieuw"
        compose.onNodeWithContentDescription("Spelers").performClick()
        compose.onNodeWithContentDescription("Speler toevoegen").performClick()
        compose.onNodeWithText("Opslaan").assertIsNotEnabled()
        compose.onNodeWithContentDescription("Naam speler").performTextInput("   ")
        compose.onNodeWithText("Opslaan").assertIsNotEnabled()
        compose.onNodeWithContentDescription("Naam speler").performTextReplacement(original)
        closeSoftKeyboard()
        compose.onNodeWithContentDescription("Backhand").performClick()
        compose.onNodeWithContentDescription("Coachingnotities").performTextInput("Rustig op de T")
        closeSoftKeyboard()
        compose.onNodeWithText("Opslaan").performClick()
        compose.onNodeWithText(original).assertIsDisplayed()

        // New activity/new store instance must read the saved data from Room.
        compose.activityRule.scenario.recreate()
        compose.onNodeWithContentDescription("Spelers").performClick()
        compose.onNodeWithContentDescription("Bewerk $original").performClick()
        compose.onNodeWithContentDescription("Naam speler").assertTextContains(original)
        compose.onNodeWithContentDescription("Coachingnotities").assertTextContains("Rustig op de T")
        compose.onNodeWithContentDescription("Naam speler").performTextReplacement(renamed)
        closeSoftKeyboard()
        compose.onNodeWithText("Opslaan").performClick()
        compose.onNodeWithText(renamed).assertIsDisplayed()
        compose.onNodeWithText(original).assertDoesNotExist()

        compose.onNodeWithContentDescription("Verwijder $renamed").performClick()
        compose.onNodeWithText("Annuleren").performClick()
        compose.onNodeWithText(renamed).assertIsDisplayed()
        compose.onNodeWithContentDescription("Verwijder $renamed").performClick()
        compose.onNodeWithText("Verwijderen").performClick()
        compose.onNodeWithText(renamed).assertDoesNotExist()
    }
}
