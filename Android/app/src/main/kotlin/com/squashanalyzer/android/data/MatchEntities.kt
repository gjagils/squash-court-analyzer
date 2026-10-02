package com.squashanalyzer.android.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.PrimaryKey
import java.util.UUID

/**
 * Mirrors SquashAnalyzer/Models/SavedMatch.swift, flattened for Room. Every
 * enum-typed field on the Swift side (Player, MatchStatus, ...) is stored as
 * its raw string value here too, so a value written by one platform reads
 * back the same way on the other once matches are ever synced.
 */
@Entity(tableName = "matches")
data class MatchEntity(
    @PrimaryKey val id: String,
    val player1Name: String,
    val player2Name: String,
    val matchStartingServer: String, // Player raw value
    val bestOf: Int,
    val savedAt: Long, // epoch millis
    val updatedAt: Long,
    val status: String, // MatchStatus raw value
    val player1CoachingFocus: String, // JSON-encoded [String]
    val player2CoachingFocus: String, // JSON-encoded [String]
    val player1CoachingNotes: String,
    val player2CoachingNotes: String,
    val player1GamesBefore: Int,
    val player2GamesBefore: Int,
    val player1GamesAfter: Int,
    val player2GamesAfter: Int,
    val player1Id: String?,
    val player2Id: String?,
)

@Entity(
    tableName = "games",
    foreignKeys = [
        ForeignKey(
            entity = MatchEntity::class,
            parentColumns = ["id"],
            childColumns = ["matchId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
)
data class GameEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(index = true) val matchId: String,
    val gameNumber: Int,
    val player1Name: String,
    val player2Name: String,
    val player1Score: Int,
    val player2Score: Int,
    val startingServer: String, // Player raw value
    val winner: String?, // Player raw value, null while unfinished
    val savedAt: Long,
    @ColumnInfo(defaultValue = "NULL") val serviceState: String? = null,
)

@Entity(
    tableName = "points",
    foreignKeys = [
        ForeignKey(
            entity = GameEntity::class,
            parentColumns = ["id"],
            childColumns = ["gameId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
)
data class PointEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(index = true) val gameId: String,
    val pointNumber: Int,
    val scorer: String, // Player raw value
    val pointType: String, // PointType raw value
    val zone: String, // CourtZone raw value, "" when not applicable
    val shotType: String, // ShotType raw value, "" when not applicable
    val server: String, // Player raw value
    val player1Score: Int,
    val player2Score: Int,
    val timestamp: Long,
    val duration: Double,
    /** Volley switch ("Uit de lucht"), version 7 */
    @ColumnInfo(defaultValue = "0") val isVolley: Boolean = false,
    /** Kind of unforced error (ErrorKind raw value, "" = not recorded), version 9 */
    @ColumnInfo(defaultValue = "") val errorKind: String = "",
)

@Entity(
    tableName = "lets",
    foreignKeys = [
        ForeignKey(
            entity = GameEntity::class,
            parentColumns = ["id"],
            childColumns = ["gameId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
)
data class LetEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(index = true) val gameId: String,
    val letNumber: Int,
    val requestedBy: String, // Player raw value
    val server: String, // Player raw value
    val player1Score: Int,
    val player2Score: Int,
    val timestamp: Long,
)

/** Generates a fresh id the same shape as Swift's `UUID().uuidString`. */
fun newId(): String = UUID.randomUUID().toString().uppercase()
