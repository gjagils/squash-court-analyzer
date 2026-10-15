package com.squashanalyzer.android.live

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject

/**
 * Debug builds only: shows the live score notification for a sample match,
 * without a server or FCM, through the same path as a push
 * (LiveFollowMessagingService.handle). For screenshots and checking texts:
 *
 *   adb shell am broadcast -a com.squashanalyzer.android.debug.LIVE_SAMPLE \
 *     -n com.squashanalyzer.android/.live.LiveScoreSampleReceiver --es state gamebal
 *
 * state: spel (default), gamebal, matchbal, pauze, uitslag, stop.
 */
class LiveScoreSampleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val match = FollowedMatch(SAMPLE_ID, SAMPLE_SERVER)
        val followed = FollowedMatches(context)
        val state = intent.getStringExtra("state") ?: "spel"
        if (state == "stop") {
            followed.remove(match)
            LiveScoreNotifier(context).cancel(match)
            return
        }
        followed.add(match)
        val snapshot = when (state) {
            "gamebal" -> snapshot(listOf(11 to 8), 10 to 8, 1 to 0, server = 1, side = "L", status = "playing")
            "matchbal" -> snapshot(listOf(11 to 8, 9 to 11, 11 to 6), 10 to 7, 2 to 1, server = 1, side = "R", status = "playing")
            "pauze" -> snapshot(listOf(11 to 8, 9 to 11), 9 to 11, 1 to 1, server = 2, side = "R", status = "between")
            "uitslag" -> snapshot(listOf(11 to 8, 9 to 11, 11 to 6, 11 to 9), 11 to 9, 3 to 1, server = 1, side = "L", status = "finished", winner = 1)
            else -> snapshot(listOf(11 to 8), 9 to 7, 1 to 0, server = 2, side = "L", status = "playing")
        }
        val data = mapOf(
            "kind" to "live",
            "id" to SAMPLE_ID,
            "server" to SAMPLE_SERVER,
            "event" to if (state == "uitslag") "end" else "update",
            "snapshot" to snapshot.toString(),
        )
        LiveFollowMessagingService.handle(context, data)
    }

    private fun snapshot(
        games: List<Pair<Int, Int>>,
        score: Pair<Int, Int>,
        gamesWon: Pair<Int, Int>,
        server: Int,
        side: String,
        status: String,
        winner: Int? = null,
    ): JSONObject {
        val list = JSONArray()
        for ((a, b) in games) list.put(JSONArray().put(a).put(b))
        val o = JSONObject()
            .put("p1", "Gerd-Jan")
            .put("p2", "Thomas")
            .put("bestOf", 5)
            .put("games", list)
            .put("score", JSONArray().put(score.first).put(score.second))
            .put("gamesWon", JSONArray().put(gamesWon.first).put(gamesWon.second))
            .put("server", server)
            .put("side", side)
            .put("status", status)
        if (winner != null) o.put("winner", winner)
        return o
    }

    private companion object {
        const val SAMPLE_ID = "voorbeeld234"
        const val SAMPLE_SERVER = "https://live.squashanalyzer.com"
    }
}
