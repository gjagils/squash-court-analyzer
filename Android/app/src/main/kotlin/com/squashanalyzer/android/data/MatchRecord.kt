package com.squashanalyzer.android.data

/**
 * Plain, Room-agnostic mirror of the app's `Match`/`Game`/`Point`/`LetCall`
 * (see SquashAnalyzer/Models/Match.swift, Game.swift, Point.swift, Let.swift).
 * `MatchStore` takes and returns these, never Room entities directly, so the
 * storage schema can change without touching every call site — same reason
 * `MatchRepository` on iOS takes `Match`, not `SavedMatch`.
 */
data class MatchRecord(
    val id: String,
    val player1Name: String,
    val player2Name: String,
    val matchStartingServer: String,
    val bestOf: Int,
    val savedAt: Long,
    val updatedAt: Long,
    val status: String,
    val player1CoachingFocus: List<String> = emptyList(),
    val player2CoachingFocus: List<String> = emptyList(),
    val player1CoachingNotes: String = "",
    val player2CoachingNotes: String = "",
    val player1GamesBefore: Int = 0,
    val player2GamesBefore: Int = 0,
    val player1GamesAfter: Int = 0,
    val player2GamesAfter: Int = 0,
    val player1Id: String? = null,
    val player2Id: String? = null,
    val games: List<GameRecord> = emptyList(),
)

data class GameRecord(
    val id: String,
    val gameNumber: Int,
    val player1Name: String,
    val player2Name: String,
    val player1Score: Int,
    val player2Score: Int,
    val startingServer: String,
    val winner: String?,
    val savedAt: Long,
    val points: List<PointRecord> = emptyList(),
    val lets: List<LetRecord> = emptyList(),
    val serviceState: String? = null,
)

data class PointRecord(
    val id: String,
    val pointNumber: Int,
    val scorer: String,
    val pointType: String,
    val zone: String,
    val shotType: String,
    val server: String,
    val player1Score: Int,
    val player2Score: Int,
    val timestamp: Long,
    val duration: Double,
    val isVolley: Boolean = false,
    val errorKind: String = "",
)

data class LetRecord(
    val id: String,
    val letNumber: Int,
    val requestedBy: String,
    val server: String,
    val player1Score: Int,
    val player2Score: Int,
    val timestamp: Long,
)

object MatchStatus {
    const val IN_PROGRESS = "inProgress"
    const val COMPLETED = "completed"
    const val ABANDONED = "abandoned"
}
