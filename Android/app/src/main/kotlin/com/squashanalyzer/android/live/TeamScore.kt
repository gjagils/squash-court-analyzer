package com.squashanalyzer.android.live

import org.json.JSONArray
import org.json.JSONObject
import squash.analyzer.core.TeamFollowStand

/**
 * One partij of a followed team match, as plain Kotlin (Core's
 * `TeamFollowPartij`, the server's push payload). Pairs are (home, away).
 */
data class TeamPartij(
    /** 1-4: E1-E4 */
    val slot: Int,
    val p1: String,
    val p2: String,
    val bestOf: Int,
    val gamesWon: Pair<Int, Int>,
    /** The game under way (or just finished) */
    val score: Pair<Int, Int>,
    /** "warmup", "playing", "between" or "finished" */
    val status: String,
    val winner: Int? = null,
    /** "retired" or "walkover" */
    val end: String? = null,
) {
    /** Decided as the server counts it: a winner, finished, given up or not played */
    val isDecided: Boolean get() = winner != null || status == "finished" || end == "retired" || end == "walkover"

    /** Being played now */
    val isLive: Boolean get() = !isDecided && (status == "playing" || status == "between")

    /** 1 home, 2 away, 0 not known */
    val winnerSide: Int
        get() {
            winner?.let { return it }
            if (!isDecided) return 0
            return when {
                gamesWon.first > gamesWon.second -> 1
                gamesWon.second > gamesWon.first -> 2
                else -> 0
            }
        }
}

/** The lock screen stand of a followed team match: the team names and the partijen that exist */
data class TeamScore(val home: String, val away: String, val partijen: List<TeamPartij>) {
    fun partij(slot: Int): TeamPartij? = partijen.firstOrNull { partij -> partij.slot == slot }

    companion object {
        /** The `team` field of an FCM data message; null when it is not a team stand */
        fun parse(json: String): TeamScore? = try {
            val o = JSONObject(json)
            val list = o.optJSONArray("partijen") ?: JSONArray()
            val partijen = mutableListOf<TeamPartij>()
            for (i in 0 until list.length()) {
                val p = list.optJSONObject(i) ?: continue
                val slot = p.optInt("slot")
                if (slot !in 1..4 || partijen.any { partij -> partij.slot == slot }) continue
                partijen.add(
                    TeamPartij(
                        slot = slot,
                        p1 = p.optString("p1").trim(),
                        p2 = p.optString("p2").trim(),
                        bestOf = p.optInt("bestOf", 5).coerceIn(1, 9),
                        gamesWon = pair(p.optJSONArray("gamesWon")),
                        score = pair(p.optJSONArray("score")),
                        status = p.optString("status", "warmup"),
                        winner = if (p.has("winner") && !p.isNull("winner")) p.optInt("winner").takeIf { it == 1 || it == 2 } else null,
                        end = if (p.has("end") && !p.isNull("end")) p.optString("end").takeIf { it == "retired" || it == "walkover" } else null,
                    ),
                )
            }
            TeamScore(
                home = o.optString("home").trim().ifEmpty { "Thuis" },
                away = o.optString("away").trim().ifEmpty { "Uit" },
                partijen = partijen.sortedBy { partij -> partij.slot },
            )
        } catch (e: Exception) {
            null
        }

        private fun pair(array: JSONArray?): Pair<Int, Int> =
            if (array == null) 0 to 0 else array.optInt(0) to array.optInt(1)

        /** The first stand, from Core (`LiveFollow.follow` read GET /api/team/:id) */
        fun from(stand: TeamFollowStand): TeamScore {
            val partijen = mutableListOf<TeamPartij>()
            for (partij in stand.partijen) {
                fun pair(values: skip.lib.Array<Int>): Pair<Int, Int> =
                    if (values.count >= 2) values[0] to values[1] else 0 to 0
                partijen.add(
                    TeamPartij(
                        slot = partij.slot, p1 = partij.p1.trim(), p2 = partij.p2.trim(), bestOf = partij.bestOf,
                        gamesWon = pair(partij.gamesWon), score = pair(partij.score), status = partij.status,
                        winner = partij.winner, end = partij.end,
                    ),
                )
            }
            return TeamScore(stand.home.trim().ifEmpty { "Thuis" }, stand.away.trim().ifEmpty { "Uit" }, partijen.sortedBy { it.slot })
        }
    }
}

/**
 * The texts, rows and bar of a team match on the lock screen (Live Update on
 * Android 16+, an ongoing notification with the four partijen before that),
 * after the design "Teamwedstrijd · Android" on the canvas.
 */
class TeamScoreCard(val score: TeamScore) {
    /** One stretch of the Live Update's bar; `player` 0 grey (not decided), 3 neutral (level, live) */
    data class Segment(val length: Int, val player: Int)

    /** One of the four rows E1-E4 */
    data class Row(
        val slot: Int,
        val label: String,
        val home: String,
        val away: String,
        /** No partij in this slot yet: "<team> E<n>", greyed */
        val missing: Boolean,
        val games1: String,
        val games2: String,
        /** "● 7–5", "klaar", "–" */
        val middle: String,
        val isLive: Boolean,
        /** 1 or 2 when decided with a winner: that box in the winner's colour */
        val winner: Int,
    )

    val homeGames: Int get() = score.partijen.sumOf { partij -> partij.gamesWon.first }
    val awayGames: Int get() = score.partijen.sumOf { partij -> partij.gamesWon.second }
    val decidedCount: Int get() = score.partijen.count { partij -> partij.isDecided }

    /** All four partijen decided: the result */
    val isFinished: Boolean get() = decidedCount == 4

    /** Partijen won by home and away */
    val partijenWon: Pair<Int, Int>
        get() = score.partijen.count { it.isDecided && it.winnerSide == 1 } to score.partijen.count { it.isDecided && it.winnerSide == 2 }

    /** "Delft 8 E2" for a partij without a name */
    fun name(partij: TeamPartij, side: Int): String {
        val given = if (side == 1) partij.p1 else partij.p2
        if (given.isNotEmpty()) return given
        return (if (side == 1) score.home else score.away) + " E" + partij.slot
    }

    private val doneText: String get() = "$decidedCount van 4 klaar"
    private val partijenText: String get() = "partijen ${partijenWon.first}–${partijenWon.second}"

    /** "All Inn 8 5 – 3 Delft 8": the title of both notifications */
    val title: String get() = "${score.home} $homeGames – $awayGames ${score.away}"

    /** The status bar chip of the Live Update: games "5–3" */
    val chipText: String get() = "$homeGames–$awayGames"

    /** The orange line above the expanded notification (shown in capitals) */
    val header: String get() = if (isFinished) "Uitslag · $partijenText" else "Competitie · $doneText"

    /** The partijen being played, by slot */
    private val live: List<TeamPartij> get() = score.partijen.filter { partij -> partij.isLive }

    /** "E2 bezig: Paul 7–5 Mark", "E2 pauze: Paul – Mark, games 1–1" */
    private fun liveText(partij: TeamPartij): String =
        if (partij.status == "between") {
            "E${partij.slot} pauze: ${name(partij, 1)} – ${name(partij, 2)}, games ${partij.gamesWon.first}–${partij.gamesWon.second}"
        } else {
            "E${partij.slot} bezig: ${name(partij, 1)} ${partij.score.first}–${partij.score.second} ${name(partij, 2)}"
        }

    /** The second line of the Live Update: the partij under way and how many are done */
    val text: String
        get() {
            if (isFinished) return "Uitslag · $partijenText"
            val playing = live
            if (playing.isEmpty()) return doneText
            val more = if (playing.size > 1) " (+${playing.size - 1})" else ""
            return liveText(playing.first()) + more + " · " + doneText
        }

    /** The second line of the collapsed ongoing notification: "E2 bezig 7–5 · 2 van 4 klaar" */
    val compactText: String
        get() {
            if (isFinished) return "Uitslag · $partijenText"
            val parts = live.map { partij ->
                if (partij.status == "between") "E${partij.slot} pauze" else "E${partij.slot} bezig ${partij.score.first}–${partij.score.second}"
            }
            return (parts + doneText).joinToString(" · ")
        }

    /** E1-E4, also the slots without a partij */
    val rows: List<Row>
        get() = (1..4).map { slot ->
            val partij = score.partij(slot)
            if (partij == null) {
                Row(slot, "E$slot", "${score.home} E$slot", "${score.away} E$slot", missing = true,
                    games1 = "–", games2 = "–", middle = "–", isLive = false, winner = 0)
            } else {
                val started = partij.isDecided || partij.isLive
                val middle = when {
                    partij.end == "walkover" -> "w.o."
                    partij.end == "retired" -> "opgave"
                    partij.isDecided -> "klaar"
                    partij.status == "between" -> "● pauze"
                    partij.isLive -> "● ${partij.score.first}–${partij.score.second}"
                    else -> "–"
                }
                Row(slot, "E$slot", name(partij, 1), name(partij, 2), missing = false,
                    games1 = if (started) partij.gamesWon.first.toString() else "–",
                    games2 = if (started) partij.gamesWon.second.toString() else "–",
                    middle = middle, isLive = partij.isLive, winner = if (partij.isDecided) partij.winnerSide else 0)
            }
        }

    /**
     * The Live Update's bar: one part per partij (E1-E4), in the winner's
     * colour when decided; the partij under way filled as far as it got
     * (games played, plus the current game) in the colour of the leader.
     */
    val segments: List<Segment>
        get() {
            val result = mutableListOf<Segment>()
            for (slot in 1..4) {
                val partij = score.partij(slot)
                when {
                    partij == null -> result.add(Segment(PART, 0))
                    partij.isDecided -> result.add(Segment(PART, partij.winnerSide.let { if (it == 0) 3 else it }))
                    partij.isLive -> {
                        val (g1, g2) = partij.gamesWon
                        val (a, b) = if (partij.status == "playing") partij.score else 0 to 0
                        val played = g1 + g2 + minOf(maxOf(a, b), 11) / 11.0
                        val filled = (PART * played / partij.bestOf.coerceAtLeast(1)).toInt().coerceIn(PART / 10, PART * 9 / 10)
                        val leader = when {
                            g1 != g2 -> if (g1 > g2) 1 else 2
                            a != b -> if (a > b) 1 else 2
                            else -> 3
                        }
                        result.add(Segment(filled, leader))
                        result.add(Segment(PART - filled, 0))
                    }
                    else -> result.add(Segment(PART, 0))
                }
            }
            return result
        }

    val progressMax: Int get() = 4 * PART

    /** The slots that have a partij (their players may have photos) */
    val slots: List<Int> get() = score.partijen.map { partij -> partij.slot }

    companion object {
        /** The length of one partij on the bar */
        const val PART = 100
    }
}
