package com.squashanalyzer.android.data

/** Plain, Room-agnostic mirror of `BadgeAwardEntity`. */
data class BadgeAwardRecord(
    val id: String,
    val cardId: String,
    val badge: String,
    val matchId: String,
    val earnedAt: Long,
    val opponentName: String,
    val awardedBy: String,
    val deletedAt: Long?,
)
