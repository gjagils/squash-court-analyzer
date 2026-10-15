package com.squashanalyzer.android.live

/**
 * One live score as the lock screen shows it: plain Kotlin values, so the
 * texts can be tested on the JVM. Comes from Core's `LiveSnapshot` (the
 * first state, when following starts) or from the snapshot JSON in an FCM
 * data message (`LiveScoreJson`). Pairs are (player 1, player 2).
 */
data class LiveScore(
    val p1: String,
    val p2: String,
    val bestOf: Int,
    /** Finished games, the one just finished included between games */
    val games: List<Pair<Int, Int>>,
    /** The game under way (or just finished) */
    val score: Pair<Int, Int>,
    /** Games won, head start included */
    val gamesWon: Pair<Int, Int>,
    /** 1 or 2 */
    val server: Int,
    /** "L" or "R" */
    val side: String,
    /** "warmup", "playing", "between" or "finished" */
    val status: String,
    val lastPoint: String? = null,
    /** 1 or 2 once the match is decided */
    val winner: Int? = null,
)

/**
 * The texts and the game bar of the live score notification (Live Update on
 * Android 16+, an ongoing notification with a mini scoreboard before that).
 * PAR-11: a game goes to 11 with two clear points.
 */
class LiveScoreCard(val score: LiveScore) {
    /** One stretch of the Live Update's game bar: `player` 0 is not played yet */
    data class Segment(val length: Int, val player: Int)

    val gamesToWin: Int get() = score.bestOf / 2 + 1
    private val p1 get() = score.p1
    private val p2 get() = score.p2
    fun name(player: Int): String = if (player == 1) p1 else p2

    val isFinished: Boolean get() = score.status == "finished"
    val isBetween: Boolean get() = score.status == "between"
    val isWarmup: Boolean get() = score.status == "warmup"

    /** The game being played (1-based): games won so far, plus this one */
    val currentGameNumber: Int get() = score.gamesWon.first + score.gamesWon.second + 1

    /** The player who wins the game with the next rally, or null */
    val gameBallFor: Int?
        get() {
            if (score.status != "playing") return null
            val (a, b) = score.score
            return when {
                a >= 10 && a > b -> 1
                b >= 10 && b > a -> 2
                else -> null
            }
        }

    /** The game ball is also the match ball */
    val isMatchBall: Boolean
        get() {
            val player = gameBallFor ?: return false
            val won = if (player == 1) score.gamesWon.first else score.gamesWon.second
            return won + 1 >= gamesToWin
        }

    private val gamesText: String get() = "${score.gamesWon.first}–${score.gamesWon.second}"
    private val sideText: String get() = if (score.side == "L") "links" else "rechts"

    /** The winner of the match (or the leader in games when the server left it out) */
    private val matchWinner: Int
        get() = score.winner ?: if (score.gamesWon.second > score.gamesWon.first) 2 else 1

    /** The status bar chip of the Live Update: "9–7", "Pauze", "3–1" */
    val chipText: String
        get() = when {
            isFinished -> {
                val w = matchWinner
                if (w == 1) gamesText else "${score.gamesWon.second}–${score.gamesWon.first}"
            }
            isBetween -> "Pauze"
            else -> "${score.score.first}–${score.score.second}"
        }

    /** "Gerd-Jan 9 – 7 Thomas"; between games and at the end it says who won */
    val title: String
        get() = when {
            isFinished -> {
                val w = matchWinner
                val (mine, theirs) = if (w == 1) score.gamesWon else score.gamesWon.second to score.gamesWon.first
                "${name(w)} wint $mine–$theirs"
            }
            isBetween && score.games.isNotEmpty() -> {
                val (a, b) = score.games.last()
                val w = if (a > b) 1 else 2
                "${name(w)} wint game ${score.games.size} met ${maxOf(a, b)}–${minOf(a, b)}"
            }
            else -> scoreLine
        }

    /** The score with the names, also the collapsed title on older Android */
    val scoreLine: String get() = "$p1 ${score.score.first} – ${score.score.second} $p2"

    /** The second line of the Live Update */
    val text: String
        get() {
            if (isFinished) return finishedGamesText
            if (isBetween) return "Games $gamesText · game $currentGameNumber begint zo"
            if (isWarmup) return "Inspelen · best of ${score.bestOf}"
            val ball = gameBallFor
            if (ball != null) {
                val kind = if (isMatchBall) "Matchbal" else "Gamebal"
                return "$kind voor ${name(ball)} · games $gamesText"
            }
            return "${name(score.server)} serveert $sideText · games $gamesText"
        }

    /** The collapsed text of the ongoing notification (Android 9-15) */
    val compactText: String
        get() {
            if (isFinished || isBetween || isWarmup) return text
            val ball = gameBallFor
            if (ball != null) return "Game $currentGameNumber · ${if (isMatchBall) "matchbal" else "gamebal"} ${name(ball)}"
            return "Game $currentGameNumber · games $gamesText · ${name(score.server)} serveert"
        }

    /** "11–8 · 6–11 · 11–7", player 1 first */
    val finishedGamesText: String
        get() = score.games.joinToString(" · ") { (a, b) -> "$a–$b" }

    /** The footer of the mini scoreboard: "Games 11–8 · 6–11" */
    val footerGames: String
        get() = if (score.games.isEmpty()) "Best of ${score.bestOf}" else "Games $finishedGamesText"

    /** The footer's right side: "Opslag rechts", or the state between and after games */
    val footerStatus: String
        get() = when {
            isFinished -> "Afgelopen"
            isBetween -> "Pauze"
            isWarmup -> "Inspelen"
            else -> "Opslag $sideText"
        }

    /** Games won per player, as pips on the mini scoreboard: (won, needed) */
    fun pips(player: Int): Pair<Int, Int> =
        (if (player == 1) score.gamesWon.first else score.gamesWon.second) to gamesToWin

    /** Points in a game on the Live Update's bar */
    val pointsPerGame: Int get() = 11

    /**
     * The game bar: one stretch of 11 per possible game. Played games in the
     * winner's colour (a head start first), the current game up to the
     * leader's points in the leader's colour, the rest not played yet (0).
     */
    val segments: List<Segment>
        get() {
            val result = mutableListOf<Segment>()
            var played1 = 0
            var played2 = 0
            for ((a, b) in score.games) if (a > b) played1++ else played2++
            repeat(maxOf(0, score.gamesWon.first - played1)) { result.add(Segment(pointsPerGame, 1)) }
            repeat(maxOf(0, score.gamesWon.second - played2)) { result.add(Segment(pointsPerGame, 2)) }
            for ((a, b) in score.games) result.add(Segment(pointsPerGame, if (a > b) 1 else 2))
            if (score.status == "playing") {
                val (a, b) = score.score
                val lead = minOf(maxOf(a, b), pointsPerGame)
                val leader = if (a > b) 1 else if (b > a) 2 else 0
                if (lead > 0 && leader != 0) {
                    result.add(Segment(lead, leader))
                    if (lead < pointsPerGame) result.add(Segment(pointsPerGame - lead, 0))
                } else {
                    result.add(Segment(pointsPerGame, 0))
                }
            }
            // Not every game is played: fill up to best of N
            var total = result.sumOf { segment -> segment.length }
            while (total < score.bestOf * pointsPerGame) {
                result.add(Segment(pointsPerGame, 0))
                total += pointsPerGame
            }
            // Adjacent stretches of one colour inside a game stay apart: segments are per game
            return result
        }

    /** How far the bar is filled: everything coloured so far */
    val progress: Int
        get() {
            var filled = 0
            for (segment in segments) {
                if (segment.player == 0) break
                filled += segment.length
            }
            return filled
        }

    val progressMax: Int get() = segments.sumOf { segment -> segment.length }
}
