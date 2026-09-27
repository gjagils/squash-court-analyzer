package com.squashanalyzer.android.data

/**
 * Plain, Room-agnostic mirror of `RefereeMatch`/`CompletedRefereeGame`/
 * `RefereePointEntry` (see Packages/SquashAnalyzerCore/Sources/
 * SquashAnalyzerCore/RefereeMatch.swift). `RefereeMatchStore` takes and
 * returns these, never Room entities directly, mirroring `MatchRecord`.
 */
data class RefereeMatchRecord(
    val id: String,
    val player1Name: String,
    val player2Name: String,
    val player1Id: String? = null,
    val player2Id: String? = null,
    val bestOf: Int,
    val player1GamesBefore: Int = 0,
    val player2GamesBefore: Int = 0,
    val player1Score: Int,
    val player2Score: Int,
    val currentServer: String,
    val serverSide: String,
    val currentGameNumber: Int,
    val player1PreferredSide: String? = null,
    val player2PreferredSide: String? = null,
    val matchStartedAt: Long,
    val gameStartedAt: Long,
    val lastPointAt: Long? = null,
    val savedAt: Long,
    val updatedAt: Long,
    val status: String,
    val completedGames: List<RefereeGameRecord> = emptyList(),
    val currentPoints: List<RefereePointRecord> = emptyList(),
)

data class RefereeGameRecord(
    val id: String,
    val number: Int,
    val player1Score: Int,
    val player2Score: Int,
    val winner: String,
    val duration: Double,
    val points: List<RefereePointRecord> = emptyList(),
)

data class RefereePointRecord(
    val id: String,
    val pointNumber: Int,
    val scorer: String,
    val score: Int,
    val side: String,
    val isStroke: Boolean,
)
