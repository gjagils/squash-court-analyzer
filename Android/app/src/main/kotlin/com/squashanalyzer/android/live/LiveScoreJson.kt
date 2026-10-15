package com.squashanalyzer.android.live

import org.json.JSONArray
import org.json.JSONObject
import squash.analyzer.core.LiveSnapshot

/** Reads a live score from the server's snapshot JSON (FCM data) or from Core's `LiveSnapshot` */
object LiveScoreJson {
    /** The `snapshot` field of an FCM data message; null when it is not a snapshot */
    fun parse(json: String): LiveScore? = try {
        val o = JSONObject(json)
        val games = mutableListOf<Pair<Int, Int>>()
        val list = o.optJSONArray("games") ?: JSONArray()
        for (i in 0 until list.length()) {
            val game = list.optJSONArray(i) ?: continue
            games.add(game.optInt(0) to game.optInt(1))
        }
        LiveScore(
            p1 = o.optString("p1", "Speler 1").ifBlank { "Speler 1" },
            p2 = o.optString("p2", "Speler 2").ifBlank { "Speler 2" },
            bestOf = o.optInt("bestOf", 5).coerceIn(1, 9),
            games = games,
            score = pair(o.optJSONArray("score")),
            gamesWon = pair(o.optJSONArray("gamesWon")),
            server = if (o.optInt("server", 1) == 2) 2 else 1,
            side = if (o.optString("side") == "L") "L" else "R",
            status = o.optString("status", "playing").let { status ->
                if (status in listOf("warmup", "playing", "between", "finished")) status else "playing"
            },
            lastPoint = if (o.has("lastPoint") && !o.isNull("lastPoint")) o.optString("lastPoint") else null,
            winner = if (o.has("winner") && !o.isNull("winner")) o.optInt("winner").takeIf { it == 1 || it == 2 } else null,
        )
    } catch (e: Exception) {
        null
    }

    private fun pair(array: JSONArray?): Pair<Int, Int> =
        if (array == null) 0 to 0 else array.optInt(0) to array.optInt(1)

    fun from(snapshot: LiveSnapshot): LiveScore {
        val games = mutableListOf<Pair<Int, Int>>()
        for (game in snapshot.games) {
            if (game.count >= 2) games.add(game[0] to game[1])
        }
        fun pair(values: skip.lib.Array<Int>): Pair<Int, Int> =
            if (values.count >= 2) values[0] to values[1] else 0 to 0
        return LiveScore(
            p1 = snapshot.p1,
            p2 = snapshot.p2,
            bestOf = snapshot.bestOf,
            games = games,
            score = pair(snapshot.score),
            gamesWon = pair(snapshot.gamesWon),
            server = snapshot.server,
            side = snapshot.side,
            status = snapshot.status.rawValue,
            lastPoint = snapshot.lastPoint,
            winner = snapshot.winner,
        )
    }
}
