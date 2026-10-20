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
    /** Who serves (1 home, 2 away) in a rally; older servers and the first stand from Core leave it out */
    val server: Int? = null,
) {
    /** Decided as the server counts it: a winner, finished, given up or not played */
    val isDecided: Boolean get() = winner != null || status == "finished" || end == "retired" || end == "walkover"

    /** Being played now */
    val isLive: Boolean get() = !isDecided && (status == "playing" || status == "between")

    /** Between two games of a partij under way */
    val isPause: Boolean get() = isLive && status == "between"

    /** The serve dot: only in a rally, when the push says who serves */
    fun isServing(side: Int): Boolean = isLive && status == "playing" && server == side

    /** "w.o." or "opgave", else null */
    val endText: String?
        get() = when (end) {
            "walkover" -> "w.o."
            "retired" -> "opgave"
            else -> null
        }

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
                        server = if (p.has("server") && !p.isNull("server")) p.optInt("server").takeIf { it == 1 || it == 2 } else null,
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
    data class Segment(val length: Int, val player: Int, val live: Boolean = false)

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
        /** "7–5", "pauze", "klaar", "–" (a live partij gets its dot in the label: "● E2") */
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

    /**
     * The winner of the evening by the SBN rule as far as the push knows it
     * (no rally points): most partijen; equal → a full line-up (a lost
     * walkover is not); → most games; → whoever won E1. 1 home, 2 away, 0 a
     * draw. As TeamScoreAttributes.teamWinner on iOS; the server's alert is leading.
     */
    val teamWinner: Int
        get() {
            val (home, away) = partijenWon
            if (home != away) return if (home > away) 1 else 2
            val full = booleanArrayOf(true, true)
            for (partij in score.partijen) {
                val winner = partij.winnerSide
                if (partij.end == "walkover" && (winner == 1 || winner == 2)) full[2 - winner] = false
            }
            if (full[0] != full[1]) return if (full[0]) 1 else 2
            if (homeGames != awayGames) return if (homeGames > awayGames) 1 else 2
            return score.partij(1)?.winnerSide ?: 0
        }

    /** "Delft 8 E2" for a partij without a name */
    fun name(partij: TeamPartij, side: Int): String {
        val given = if (side == 1) partij.p1 else partij.p2
        if (given.isNotEmpty()) return given
        return (if (side == 1) score.home else score.away) + " E" + partij.slot
    }

    private val doneText: String get() = "$decidedCount van 4 klaar"
    private val partijenText: String get() = "partijen ${partijenWon.first}–${partijenWon.second}"

    /** "games 9–6" over all partijen (secondary: SBN counts partijen first) */
    private val teamGamesText: String get() = "games $homeGames–$awayGames"

    /** "All Inn 8 1 – 1 Delft 8": the partijen won, the title of both notifications */
    val title: String get() = "${score.home} ${partijenWon.first} – ${partijenWon.second} ${score.away}"

    /** The status bar chip of the Live Update: partijen "1–1" */
    val chipText: String get() = "${partijenWon.first}–${partijenWon.second}"

    /** The partijen being played, by slot */
    val live: List<TeamPartij> get() = score.partijen.filter { partij -> partij.isLive }

    /** The top of the expanded notification (design B, 20 October 2026) */
    sealed class Focus {
        /** One partij under way, large; two (or more: two courts) as compact rows */
        data class Live(val partijen: List<TeamPartij>) : Focus()

        /** Nothing under way, not all decided: the next partij */
        data class Next(val slot: Int) : Focus()

        /** All four decided: the four results as rows */
        object Finished : Focus()
    }

    val focus: Focus
        get() {
            if (isFinished) return Focus.Finished
            val playing = live
            if (playing.isNotEmpty()) return Focus.Live(playing)
            return Focus.Next(nextSlot)
        }

    /** One warming up, else the first slot that is not decided */
    val nextSlot: Int
        get() {
            score.partijen.firstOrNull { partij -> partij.status == "warmup" && !partij.isDecided }?.let { return it.slot }
            return (1..4).firstOrNull { slot -> score.partij(slot)?.isDecided != true } ?: 1
        }

    /** "E3 · bezig", "E3 · pauze", "E3 · inspelen", "Volgende partij · E3" */
    fun focusHeading(slot: Int): String {
        val partij = score.partij(slot) ?: return "Volgende partij · E$slot"
        return when {
            partij.isPause -> "E$slot · pauze"
            partij.isLive -> "E$slot · bezig"
            partij.status == "warmup" && !partij.isDecided -> "E$slot · inspelen"
            else -> "Volgende partij · E$slot"
        }
    }

    /** "games 1–1" of one partij */
    fun gamesText(partij: TeamPartij): String = "games ${partij.gamesWon.first}–${partij.gamesWon.second}"

    /** "7–5" */
    fun pointsText(partij: TeamPartij): String = "${partij.score.first}–${partij.score.second}"

    /** One of the four boxes E1-E4: `kind` 1 home won, 2 away won, 3 decided without winner, 4 under way, 0 not started */
    data class Tile(val slot: Int, val kind: Int, val text: String)

    val tiles: List<Tile>
        get() = (1..4).map { slot ->
            val partij = score.partij(slot)
            when {
                partij == null -> Tile(slot, 0, "E$slot  –")
                partij.isDecided -> {
                    val result = partij.endText ?: "${partij.gamesWon.first}–${partij.gamesWon.second}"
                    Tile(slot, partij.winnerSide.let { if (it == 0) 3 else it }, "E$slot  $result")
                }
                partij.isLive -> Tile(slot, 4, "E$slot  bezig")
                else -> Tile(slot, 0, "E$slot  –")
            }
        }

    /** "E3 bezig: Bas 7–5 Tim (1–1)", "E3 pauze: Bas – Tim (1–1)" */
    private fun liveText(partij: TeamPartij): String {
        val games = "(${partij.gamesWon.first}–${partij.gamesWon.second})"
        return if (partij.isPause) {
            "E${partij.slot} pauze: ${name(partij, 1)} – ${name(partij, 2)} $games"
        } else {
            "E${partij.slot} bezig: ${name(partij, 1)} ${pointsText(partij)} ${name(partij, 2)} $games"
        }
    }

    /** "Uitslag · partijen 3–1 · games 9–6" */
    private val resultText: String get() = "Uitslag · $partijenText · $teamGamesText"

    /** The second line of the Live Update: the partij under way, then the games of the teams */
    val text: String
        get() {
            if (isFinished) return resultText
            val playing = live
            if (playing.isEmpty()) return "$doneText · $teamGamesText"
            val more = if (playing.size > 1) " (+${playing.size - 1})" else ""
            return liveText(playing.first()) + more + " · " + teamGamesText
        }

    /** The second line of the collapsed ongoing notification: "E2 bezig 7–5 · 2 van 4 klaar" */
    val compactText: String
        get() {
            if (isFinished) return resultText
            val parts = live.map { partij ->
                if (partij.isPause) "E${partij.slot} pauze" else "E${partij.slot} bezig ${pointsText(partij)}"
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
                // Decided: the games boxes say it, so only "w.o." or "opgave" between them
                val middle = when {
                    partij.isDecided -> partij.endText ?: "–"
                    partij.isPause -> "pauze"
                    partij.isLive -> pointsText(partij)
                    else -> "–"
                }
                Row(slot, if (partij.isLive) "● E$slot" else "E$slot", name(partij, 1), name(partij, 2), missing = false,
                    games1 = if (started) partij.gamesWon.first.toString() else "–",
                    games2 = if (started) partij.gamesWon.second.toString() else "–",
                    middle = middle, isLive = partij.isLive, winner = if (partij.isDecided) partij.winnerSide else 0)
            }
        }

    /**
     * The Live Update's bar: one part per partij (E1-E4), in the winner's
     * colour when decided, grey before the start. A partij under way is its
     * leader's colour, faded (`live`). Not partly filled: a second segment
     * or a progress point splits the part with a gap, which read as five
     * partijen on the emulator.
     */
    val segments: List<Segment>
        get() = (1..4).map { slot ->
            val partij = score.partij(slot)
            when {
                partij == null -> Segment(PART, 0)
                partij.isDecided -> Segment(PART, partij.winnerSide.let { if (it == 0) 3 else it })
                partij.isLive -> Segment(PART, leader(partij), live = true)
                else -> Segment(PART, 0)
            }
        }

    /** Ahead in games, else in points; 3 level */
    private fun leader(partij: TeamPartij): Int {
        val (g1, g2) = partij.gamesWon
        val (a, b) = if (partij.status == "playing") partij.score else 0 to 0
        return when {
            g1 != g2 -> if (g1 > g2) 1 else 2
            a != b -> if (a > b) 1 else 2
            else -> 3
        }
    }

    val progressMax: Int get() = 4 * PART

    /** The slots that have a partij (their players may have photos) */
    val slots: List<Int> get() = score.partijen.map { partij -> partij.slot }

    companion object {
        /** The length of one partij on the bar */
        const val PART = 100
    }
}
