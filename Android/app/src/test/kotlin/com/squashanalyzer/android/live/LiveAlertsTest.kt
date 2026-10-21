package com.squashanalyzer.android.live

import android.Manifest
import android.app.Application
import android.app.Notification
import android.app.NotificationManager
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.json.JSONArray
import org.json.JSONObject

/** "Melding bij elke game": which pushes alert, and how (a separate heads-up next to the score) */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, qualifiers = "nl")
class LiveAlertsTest {
    private val app: Application = ApplicationProvider.getApplicationContext()
    private val manager get() = app.getSystemService(NotificationManager::class.java)
    private val match = FollowedMatch("abcdefgh2345", "https://live.squashanalyzer.com")
    private val team = FollowedMatch("teamabcd2345", "https://live.squashanalyzer.com", FollowedMatch.TEAM)

    @Before fun allow() {
        shadowOf(app).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
    }

    @After fun clean() {
        app.getSharedPreferences("defaults", 0).edit().clear().commit()
        app.getSharedPreferences("squash-live-follow", 0).edit().clear().commit()
    }

    // The decision

    @Test fun anAlertNeedsATitleAndTheSettingOn() {
        val data = mapOf("alertTitle" to " Thomas wint game 2 ", "alertBody" to "Gerd-Jan 1 – 1 Thomas")
        assertEquals(LiveAlerts.Alert("Thomas wint game 2", "Gerd-Jan 1 – 1 Thomas"), LiveAlerts.from(data, enabled = true))
        assertNull(LiveAlerts.from(data, enabled = false))
        assertNull(LiveAlerts.from(mapOf("alertBody" to "x"), enabled = true))
        assertNull(LiveAlerts.from(mapOf("alertTitle" to "  "), enabled = true))
        assertEquals(LiveAlerts.Alert("Uitslag", ""), LiveAlerts.from(mapOf("alertTitle" to "Uitslag"), enabled = true))
    }

    @Test fun theSettingIsOnByDefaultAndReadFromSkipsDefaults() {
        assertTrue(LiveAlerts.isOn(app))
        app.getSharedPreferences("defaults", 0).edit().putBoolean("liveLockScreenAlerts", false).commit()
        assertFalse(LiveAlerts.isOn(app))
        app.getSharedPreferences("defaults", 0).edit().putString("liveLockScreenAlerts", "true").commit()
        assertTrue(LiveAlerts.isOn(app))
    }

    // The notification

    @Test @Config(sdk = [34])
    fun anAlertIsASeparateHeadsUpNextToTheScore() {
        val notifier = LiveScoreNotifier(app)
        notifier.show(match, score())
        notifier.alert(match, LiveAlerts.Alert("Thomas wint game 2", "Gerd-Jan 1 – 1 Thomas"))
        assertEquals(2, manager.activeNotifications.size)
        val alert = manager.activeNotifications.single { it.id == LiveScoreNotifier.alertId(match) }.notification
        assertEquals(LiveScoreNotifier.ALERT_CHANNEL_ID, alert.channelId)
        assertEquals("Thomas wint game 2", alert.extras.getString(Notification.EXTRA_TITLE))
        assertTrue(alert.flags and Notification.FLAG_AUTO_CANCEL != 0)
        assertFalse(alert.flags and Notification.FLAG_ONGOING_EVENT != 0)
        assertTrue(alert.contentIntent != null)
        val channel = manager.getNotificationChannel(LiveScoreNotifier.ALERT_CHANNEL_ID)
        assertEquals("Uitslagen en games", channel.name)
        assertEquals(NotificationManager.IMPORTANCE_HIGH, channel.importance)
        assertNotEquals(LiveScoreNotifier.alertId(match), LiveScoreNotifier.notificationId(match))
    }

    @Test @Config(sdk = [34])
    fun theNextAlertOfAMatchReplacesItsLastOne() {
        val notifier = LiveScoreNotifier(app)
        notifier.alert(match, LiveAlerts.Alert("Gerd-Jan wint game 1", ""))
        notifier.alert(match, LiveAlerts.Alert("Thomas wint game 2", ""))
        notifier.alert(team, LiveAlerts.Alert("E1: Paul wint 3–0", ""))
        assertEquals(2, manager.activeNotifications.size)
        val alert = manager.activeNotifications.single { it.id == LiveScoreNotifier.alertId(match) }.notification
        assertEquals("Thomas wint game 2", alert.extras.getString(Notification.EXTRA_TITLE))
        notifier.cancelAlert(match)
        assertEquals(1, manager.activeNotifications.size)
    }

    // A push, end to end through the messaging service

    @Test @Config(sdk = [34])
    fun aGameAlertInAPushShowsTheScoreAndTheAlert() {
        FollowedMatches(app).add(match)
        LiveFollowMessagingService.handle(app, livePush(alertTitle = "Gerd-Jan wint game 1"))
        assertEquals(2, manager.activeNotifications.size)
        val score = manager.activeNotifications.single { it.id == LiveScoreNotifier.notificationId(match) }.notification
        assertEquals(LiveScoreNotifier.CHANNEL_ID, score.channelId)
    }

    @Test @Config(sdk = [34])
    fun noAlertWhenTheSettingIsOff() {
        app.getSharedPreferences("defaults", 0).edit().putBoolean("liveLockScreenAlerts", false).commit()
        FollowedMatches(app).add(match)
        LiveFollowMessagingService.handle(app, livePush(alertTitle = "Gerd-Jan wint game 1"))
        assertEquals(listOf(LiveScoreNotifier.notificationId(match)), manager.activeNotifications.map { it.id })
    }

    @Test @Config(sdk = [34])
    fun noAlertForAMatchNotFollowed() {
        LiveFollowMessagingService.handle(app, livePush(alertTitle = "Gerd-Jan wint game 1"))
        assertTrue(manager.activeNotifications.isEmpty())
    }

    @Test @Config(sdk = [34])
    fun aTeamPushShowsTheTeamNotification() {
        FollowedMatches(app).add(team)
        LiveFollowMessagingService.handle(app, teamPush(alertTitle = "E1: Paul wint 3–0"))
        val n = manager.activeNotifications.single { it.id == LiveScoreNotifier.notificationId(team) }.notification
        assertEquals("All Inn 8 1 – 0 Delft 8", n.extras.getString(Notification.EXTRA_TITLE))
        assertEquals("E2 bezig 4–2 · 1 van 4 klaar", n.extras.getString(Notification.EXTRA_TEXT))
        assertTrue(n.flags and Notification.FLAG_ONGOING_EVENT != 0)
        assertTrue(n.bigContentView != null && n.contentView != null)
        assertEquals("Stoppen", n.actions.single().title.toString())
        val alert = manager.activeNotifications.single { it.id == LiveScoreNotifier.alertId(team) }.notification
        assertEquals("E1: Paul wint 3–0", alert.extras.getString(Notification.EXTRA_TITLE))
    }

    @Test @Config(sdk = [36])
    fun aTeamMatchOnAndroid16IsALiveUpdate() {
        FollowedMatches(app).add(team)
        LiveFollowMessagingService.handle(app, teamPush())
        val n = manager.activeNotifications.single().notification
        assertEquals("All Inn 8 1 – 0 Delft 8", n.extras.getString(Notification.EXTRA_TITLE))
        assertEquals("E2 bezig: Paul 4–2 Mark (0–0) · games 3–0", n.extras.getString(Notification.EXTRA_TEXT))
        assertEquals("1–0", n.shortCriticalText)
        assertTrue(n.extras.getBoolean("android.requestPromotedOngoing"))
        assertTrue(n.bigContentView == null && n.contentView == null)
    }

    @Test @Config(sdk = [34])
    fun aTeamEndBeforeTheResultRemovesItAndForgetsTheMatch() {
        FollowedMatches(app).add(team)
        LiveFollowMessagingService.handle(app, teamPush())
        LiveFollowMessagingService.handle(app, teamPush(event = "end"))
        assertTrue(manager.activeNotifications.isEmpty())
        assertFalse(FollowedMatches(app).contains(team))
    }

    private fun score() = LiveScore(
        p1 = "Gerd-Jan", p2 = "Thomas", bestOf = 5, games = listOf(11 to 8), score = 9 to 7,
        gamesWon = 1 to 0, server = 1, side = "R", status = "playing",
    )

    private fun livePush(alertTitle: String? = null): Map<String, String> {
        val snapshot = JSONObject().put("p1", "Gerd-Jan").put("p2", "Thomas").put("bestOf", 5)
            .put("games", JSONArray().put(JSONArray().put(11).put(8)))
            .put("score", JSONArray().put(0).put(0)).put("gamesWon", JSONArray().put(1).put(0))
            .put("server", 1).put("side", "R").put("status", "between")
        val data = mutableMapOf("kind" to "live", "id" to match.id, "server" to match.server, "event" to "update",
            "snapshot" to snapshot.toString())
        if (alertTitle != null) {
            data["alertTitle"] = alertTitle
            data["alertBody"] = "Gerd-Jan 1 – 0 Thomas"
        }
        return data
    }

    private fun teamPush(event: String = "update", alertTitle: String? = null): Map<String, String> {
        val stand = """{"home":"All Inn 8","away":"Delft 8","partijen":[
            {"slot":1,"p1":"Paul","p2":"Thomas","bestOf":5,"gamesWon":[3,0],"score":[11,4],"status":"finished","winner":1},
            {"slot":2,"p1":"Paul","p2":"Mark","bestOf":5,"gamesWon":[0,0],"score":[4,2],"status":"playing"}]}"""
        val data = mutableMapOf("kind" to "team", "id" to team.id, "server" to team.server, "event" to event, "team" to stand)
        if (alertTitle != null) {
            data["alertTitle"] = alertTitle
            data["alertBody"] = "All Inn 8 3 – 0 Delft 8"
        }
        return data
    }
}
