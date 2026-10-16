package com.squashanalyzer.android.live

import android.Manifest
import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/** The notification itself: Android 9-15 (ongoing, mini scoreboard) and 16+ (Live Update) */
@RunWith(RobolectricTestRunner::class)
// A plain Application: SquashApplication starts Skip, which can only happen once per JVM (two SDKs here)
@Config(application = Application::class)
class LiveScoreNotifierTest {
    private val app: Application = ApplicationProvider.getApplicationContext()
    private val manager get() = app.getSystemService(NotificationManager::class.java)
    private val match = FollowedMatch("abcdefgh2345", "https://live.squashanalyzer.com")

    private fun score(status: String = "playing", winner: Int? = null) = LiveScore(
        p1 = "Gerd-Jan", p2 = "Thomas", bestOf = 5, games = listOf(11 to 8),
        score = if (status == "finished") 11 to 9 else 9 to 7,
        gamesWon = if (status == "finished") 3 to 1 else 1 to 0,
        server = 1, side = "R", status = status, winner = winner,
    )

    @Before fun allow() {
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
    }

    private fun shown(): Notification = manager.activeNotifications.single().notification

    @Test @Config(sdk = [34])
    fun olderAndroidShowsAnOngoingScoreboard() {
        LiveScoreNotifier(app).show(match, score())
        val n = shown()
        assertEquals(LiveScoreNotifier.CHANNEL_ID, n.channelId)
        assertEquals("Gerd-Jan 9 – 7 Thomas", n.extras.getString(Notification.EXTRA_TITLE))
        assertTrue(n.flags and Notification.FLAG_ONGOING_EVENT != 0)
        assertEquals(Notification.VISIBILITY_PUBLIC, n.visibility)
        assertEquals("Stoppen", n.actions.single().title.toString())
        // The ticker: collapsed one line, expanded the whole board
        assertTrue(n.bigContentView != null)
        assertTrue(n.contentView != null)
    }

    @Test @Config(sdk = [36])
    fun debugBuildsCanShowTheTickerOnAndroid16() {
        val prefs = LiveScoreNotifier.debugPrefs(app)
        prefs.edit().putBoolean(LiveScoreNotifier.DEBUG_FORCE_ONGOING, true).commit()
        try {
            LiveScoreNotifier(app).show(match, score())
            val n = shown()
            assertTrue(n.bigContentView != null)
            assertFalse(n.extras.getBoolean("android.requestPromotedOngoing"))
        } finally {
            prefs.edit().clear().commit()
        }
    }

    @Test @Config(sdk = [36])
    fun android16ShowsALiveUpdate() {
        LiveScoreNotifier(app).show(match, score())
        val n = shown()
        assertEquals("Gerd-Jan 9 – 7 Thomas", n.extras.getString(Notification.EXTRA_TITLE))
        assertEquals("9–7", n.shortCriticalText)
        assertTrue(n.extras.getBoolean("android.requestPromotedOngoing"))
        assertTrue(n.flags and Notification.FLAG_ONGOING_EVENT != 0)
        // No custom views: a promoted notification may not have them
        assertTrue(n.bigContentView == null && n.contentView == null)
        // Both avatars (initials here) as the large icon
        assertTrue(n.getLargeIcon() != null)
    }

    @Test @Config(sdk = [36])
    fun theFinalScoreIsNotOngoingAndHasNoStopButton() {
        val notifier = LiveScoreNotifier(app)
        notifier.show(match, score())
        notifier.show(match, score(status = "finished", winner = 1))
        val n = shown()
        assertEquals("Gerd-Jan wint 3–1", n.extras.getString(Notification.EXTRA_TITLE))
        assertFalse(n.flags and Notification.FLAG_ONGOING_EVENT != 0)
        assertTrue(n.actions == null || n.actions.isEmpty())
        assertFalse(n.extras.getBoolean("android.requestPromotedOngoing"))
    }

    @Test @Config(sdk = [34])
    fun cancelRemovesIt() {
        val notifier = LiveScoreNotifier(app)
        notifier.show(match, score())
        notifier.cancel(match)
        assertTrue(manager.activeNotifications.isEmpty())
    }

    @Test @Config(sdk = [34])
    fun nothingWithoutPermission() {
        shadowOf(app).denyPermissions(Manifest.permission.POST_NOTIFICATIONS)
        LiveScoreNotifier(app).show(match, score())
        assertTrue(manager.activeNotifications.isEmpty())
    }
}
