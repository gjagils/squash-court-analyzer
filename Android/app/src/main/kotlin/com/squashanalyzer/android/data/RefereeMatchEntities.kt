package com.squashanalyzer.android.data

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.PrimaryKey

/**
 * Mirrors SquashAnalyzerCore's `RefereeMatch`/`RefereePointEntry`, flattened
 * for Room. Simpler than the coach schema: referee mode has no point type,
 * zone or shot tagging, just who scored, the service side and whether the
 * rally was a stroke.
 */
@Entity(tableName = "referee_matches")
data class RefereeMatchEntity(
    @PrimaryKey val id: String,
    val player1Name: String,
    val player2Name: String,
    val player1Id: String?,
    val player2Id: String?,
    val bestOf: Int,
    val player1GamesBefore: Int,
    val player2GamesBefore: Int,
    val player1Score: Int,
    val player2Score: Int,
    val currentServer: String, // Player raw value
    val serverSide: String, // ServerSide raw value
    val currentGameNumber: Int,
    val player1PreferredSide: String?, // ServerSide raw value
    val player2PreferredSide: String?, // ServerSide raw value
    val openingServer: String? = null, // Player raw value: who served the first rally of this game
    val openingSide: String? = null, // ServerSide raw value
    val matchStartedAt: Long,
    val gameStartedAt: Long,
    val lastPointAt: Long?,
    val savedAt: Long,
    val updatedAt: Long,
    val status: String, // MatchStatus raw value
)

@Entity(
    tableName = "referee_games",
    foreignKeys = [
        ForeignKey(
            entity = RefereeMatchEntity::class,
            parentColumns = ["id"],
            childColumns = ["matchId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
)
data class RefereeGameEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(index = true) val matchId: String,
    val number: Int,
    val player1Score: Int,
    val player2Score: Int,
    val winner: String, // Player raw value
    val duration: Double,
)

@Entity(
    tableName = "referee_points",
    foreignKeys = [
        ForeignKey(
            entity = RefereeGameEntity::class,
            parentColumns = ["id"],
            childColumns = ["gameId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
)
data class RefereePointEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(index = true) val gameId: String,
    val pointNumber: Int,
    val scorer: String, // Player raw value
    val score: Int,
    val side: String, // ServerSide raw value
    val isStroke: Boolean,
)

/**
 * The current, unfinished game's rally history is not tied to any completed
 * `RefereeGameEntity` row, so it gets its own table keyed by match instead of
 * game id.
 */
@Entity(
    tableName = "referee_current_points",
    foreignKeys = [
        ForeignKey(
            entity = RefereeMatchEntity::class,
            parentColumns = ["id"],
            childColumns = ["matchId"],
            onDelete = ForeignKey.CASCADE,
        )
    ],
)
data class RefereeCurrentPointEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(index = true) val matchId: String,
    val pointNumber: Int,
    val scorer: String, // Player raw value
    val score: Int,
    val side: String, // ServerSide raw value
    val isStroke: Boolean,
)
