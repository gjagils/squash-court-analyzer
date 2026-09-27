package com.squashanalyzer.android

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import org.junit.Rule
import org.junit.Test
import skip.ui.ColorScheme
import skip.ui.ComposeContext
import skip.ui.PresentationRoot
import squash.analyzer.core.Player
import squash.analyzer.ui.CourtView

/**
 * Mounts CourtView directly (not through MainActivity/AndroidHomeView, since
 * coach mode's own screen doesn't exist on Android yet — see phase 5 in
 * docs/android-port.md). This is the highest transpile-risk view in the app
 * (custom Path drawing, gradients, a tap gesture on a private @State-backed
 * struct), so it gets its own real render-and-tap test rather than only a
 * Kotlin-compiles check.
 */
class CourtViewTest {
    @get:Rule val compose = createComposeRule()

    @Test fun rendersInteractiveZonesAndReportsTaps() {
        var tapped: String? = null
        compose.setContent {
            PresentationRoot(defaultColorScheme = ColorScheme.dark, context = ComposeContext()) { context ->
                Box(modifier = context.modifier.fillMaxSize()) {
                    CourtView(isInteractive = true, selectedPlayer = Player.player1, onZoneTapped = { zone -> tapped = zone.rawValue }).Compose(context = context.content())
                }
            }
        }

        compose.onNodeWithText("KIES EEN ZONE").assertIsDisplayed()
        compose.onNodeWithContentDescription("Zone Voor Links").assertIsDisplayed().performClick()
        // The tap has a deliberate 100ms visual delay (see ZoneTapArea's
        // DispatchQueue.main.asyncAfter) before invoking onTap, which isn't
        // tracked by Compose's own idle detection — poll instead of
        // waitForIdle().
        compose.waitUntil(timeoutMillis = 2_000) { tapped != null }
        assert(tapped == "Voor Links") { "expected 'Voor Links', got $tapped" }
    }

    @Test fun hidesInstructionAndZonesWhenNotInteractive() {
        compose.setContent {
            PresentationRoot(defaultColorScheme = ColorScheme.dark, context = ComposeContext()) { context ->
                Box(modifier = context.modifier.fillMaxSize()) {
                    CourtView(isInteractive = false, selectedPlayer = null, onZoneTapped = null).Compose(context = context.content())
                }
            }
        }

        compose.onNodeWithText("KIES EEN ZONE").assertDoesNotExist()
        compose.onNodeWithContentDescription("Zone Voor Links").assertDoesNotExist()
    }
}
