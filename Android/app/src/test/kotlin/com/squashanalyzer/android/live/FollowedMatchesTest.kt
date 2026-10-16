package com.squashanalyzer.android.live

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** The followed matches across restarts, team matches included, and the entries of older builds */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class FollowedMatchesTest {
    private val app: Application = ApplicationProvider.getApplicationContext()
    private val server = "https://live.squashanalyzer.com"

    @After fun clean() {
        app.getSharedPreferences("squash-live-follow", 0).edit().clear().commit()
    }

    @Test fun keepsTheKind() {
        val followed = FollowedMatches(app)
        val single = FollowedMatch("abcdefgh2345", server)
        val team = FollowedMatch("teamabcd2345", server, FollowedMatch.TEAM)
        followed.add(single)
        followed.add(team)
        assertEquals(setOf(single, team), followed.all().toSet())
        assertTrue(followed.contains(team))
        // The same id as a single match is another follow
        assertFalse(followed.contains(FollowedMatch("teamabcd2345", server)))
        followed.remove(team)
        assertEquals(listOf(single), followed.all())
    }

    @Test fun entriesOfOlderBuildsAreSingleMatches() {
        app.getSharedPreferences("squash-live-follow", 0).edit()
            .putStringSet("following", setOf("abcdefgh2345 $server")).commit()
        assertEquals(listOf(FollowedMatch("abcdefgh2345", server)), FollowedMatches(app).all())
    }

    @Test fun theEntry() {
        assertEquals("teamabcd2345 $server team", FollowedMatches.entry(FollowedMatch("teamabcd2345", server, "team")))
        assertEquals("abcdefgh2345 $server", FollowedMatches.entry(FollowedMatch("abcdefgh2345", server)))
        assertNull(FollowedMatches.parse("abcdefgh2345 $server other"))
        assertNull(FollowedMatches.parse("abcdefgh2345 https://example.com team"))
    }

    @Test fun theTargetAndApi() {
        val team = FollowedMatch("teamabcd2345", server, FollowedMatch.TEAM)
        assertTrue(team.toTarget().isTeam)
        assertEquals("$server/api/team/teamabcd2345", team.apiUrl)
        assertEquals("$server/api/live/abcdefgh2345", FollowedMatch("abcdefgh2345", server).apiUrl)
        assertEquals(team, FollowedMatch.from(team.toTarget()))
        assertEquals(team, FollowedMatch.validated("teamabcd2345", server, "team"))
        assertEquals(FollowedMatch("teamabcd2345", server), FollowedMatch.validated("teamabcd2345", server, "live"))
    }
}
