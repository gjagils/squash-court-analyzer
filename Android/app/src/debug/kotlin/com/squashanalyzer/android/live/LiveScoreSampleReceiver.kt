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
 * `--es team spel|pauze|twee|tussen|uitslag|stop` shows a team match instead;
 * `--es alertTitle "…" --es alertBody "…"` adds an alert as the server does.
 *
 * `--es style ongoing` shows the Android 9-15 notification (the ticker with
 * custom views) on Android 16+ as well, for every live score after it, also
 * real pushes; `--es style live` switches back to the Live Update.
 */
class LiveScoreSampleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val match = FollowedMatch(SAMPLE_ID, SAMPLE_SERVER)
        val followed = FollowedMatches(context)
        when (intent.getStringExtra("style")) {
            "ongoing" -> LiveScoreNotifier.debugPrefs(context).edit().putBoolean(LiveScoreNotifier.DEBUG_FORCE_ONGOING, true).apply()
            "live" -> LiveScoreNotifier.debugPrefs(context).edit().putBoolean(LiveScoreNotifier.DEBUG_FORCE_ONGOING, false).apply()
        }
        intent.getStringExtra("team")?.let { teamState ->
            team(context, intent, teamState)
            return
        }
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
            else -> snapshot(listOf(11 to 8), 9 to 7, 1 to 0, server = 2, side = "L", status = "playing", lastPoint = "Thomas: Winner · Volley drop")
        }
        val data = mutableMapOf(
            "kind" to "live",
            "id" to SAMPLE_ID,
            "server" to SAMPLE_SERVER,
            "event" to if (state == "uitslag") "end" else "update",
            "snapshot" to snapshot.toString(),
        )
        alert(intent, data)
        LiveFollowMessagingService.handle(context, data)
    }

    /** `--es alertTitle "…" --es alertBody "…"`: as the server's "Melding bij elke game" */
    private fun alert(intent: Intent, data: MutableMap<String, String>) {
        intent.getStringExtra("alertTitle")?.let { data["alertTitle"] = it }
        intent.getStringExtra("alertBody")?.let { data["alertBody"] = it }
    }

    /**
     * `--es team spel|pauze|twee|tussen|uitslag|stop`: a team match, All Inn 8 – Delft 8
     * (E1 and E3 decided, E2 under way, E4 not started; uitslag: all four).
     */
    private fun team(context: Context, intent: Intent, state: String) {
        val match = FollowedMatch(SAMPLE_TEAM_ID, SAMPLE_SERVER, FollowedMatch.TEAM)
        val followed = FollowedMatches(context)
        if (state == "stop") {
            followed.remove(match)
            LiveScoreNotifier(context).cancel(match)
            LiveScoreNotifier(context).cancelAlert(match)
            return
        }
        followed.add(match)
        val partijen = JSONArray()
            .put(partij(1, "Gerd-Jan", "Thomas", 3 to 0, 11 to 6, "finished", winner = 1))
        when (state) {
            "uitslag" -> partijen
                .put(partij(2, "Paul", "Mark", 3 to 1, 11 to 9, "finished", winner = 1))
                .put(partij(3, "Luis", "Niels", 1 to 3, 7 to 11, "finished", winner = 2))
                .put(partij(4, "Anna", "", 0 to 3, 0 to 0, "finished", winner = 2, end = "walkover"))
            "pauze" -> partijen
                .put(partij(2, "Paul", "Mark", 1 to 1, 9 to 11, "between"))
                .put(partij(3, "Luis", "Niels", 1 to 3, 7 to 11, "finished", winner = 2))
            "twee" -> partijen
                .put(partij(2, "Paul", "Mark", 1 to 0, 7 to 5, "playing", server = 1))
                .put(partij(3, "Luis", "Niels", 0 to 1, 4 to 6, "playing", server = 2))
            "tussen" -> partijen
                .put(partij(2, "Paul", "Mark", 1 to 3, 7 to 11, "finished", winner = 2))
                .put(partij(3, "Luis", "Niels", 0 to 0, 0 to 0, "warmup"))
            else -> partijen
                .put(partij(2, "Paul", "Mark", 1 to 0, 7 to 5, "playing", server = 1))
                .put(partij(3, "Luis", "Niels", 1 to 3, 7 to 11, "finished", winner = 2))
                .put(partij(4, "Anna", "Bram", 0 to 0, 0 to 0, "warmup"))
        }
        val stand = JSONObject().put("home", "All Inn Squash 8").put("away", "Squash Delft 8").put("partijen", partijen)
        val data = mutableMapOf(
            "kind" to "team",
            "id" to SAMPLE_TEAM_ID,
            "server" to SAMPLE_SERVER,
            "event" to if (state == "uitslag") "end" else "update",
            "team" to stand.toString(),
        )
        alert(intent, data)
        LiveFollowMessagingService.handle(context, data)
    }

    private fun partij(
        slot: Int, p1: String, p2: String, gamesWon: Pair<Int, Int>, score: Pair<Int, Int>, status: String,
        winner: Int? = null, end: String? = null, server: Int? = null,
    ): JSONObject {
        val o = JSONObject()
            .put("slot", slot).put("p1", p1).put("p2", p2).put("bestOf", 5)
            .put("gamesWon", JSONArray().put(gamesWon.first).put(gamesWon.second))
            .put("score", JSONArray().put(score.first).put(score.second))
            .put("status", status)
        if (winner != null) o.put("winner", winner)
        if (end != null) o.put("end", end)
        if (server != null) o.put("server", server)
        return o
    }

    private fun snapshot(
        games: List<Pair<Int, Int>>,
        score: Pair<Int, Int>,
        gamesWon: Pair<Int, Int>,
        server: Int,
        side: String,
        status: String,
        winner: Int? = null,
        lastPoint: String? = null,
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
        if (lastPoint != null) o.put("lastPoint", lastPoint)
        return o
    }

    private companion object {
        const val SAMPLE_ID = "voorbeeld234"
        const val SAMPLE_TEAM_ID = "voorbeeldt23"
        const val SAMPLE_SERVER = "https://live.squashanalyzer.com"
    }
}
