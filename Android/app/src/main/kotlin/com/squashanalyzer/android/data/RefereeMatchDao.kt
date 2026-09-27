package com.squashanalyzer.android.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction

@Dao
interface RefereeMatchDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMatch(match: RefereeMatchEntity)

    @Query("DELETE FROM referee_games WHERE matchId = :matchId")
    suspend fun deleteGamesForMatch(matchId: String)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertGames(games: List<RefereeGameEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPoints(points: List<RefereePointEntity>)

    @Query("DELETE FROM referee_current_points WHERE matchId = :matchId")
    suspend fun deleteCurrentPointsForMatch(matchId: String)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCurrentPoints(points: List<RefereeCurrentPointEntity>)

    @Query("SELECT * FROM referee_matches WHERE id = :id LIMIT 1")
    suspend fun matchById(id: String): RefereeMatchEntity?

    @Query("SELECT * FROM referee_matches WHERE status = :status ORDER BY updatedAt DESC LIMIT 1")
    suspend fun mostRecentMatchWithStatus(status: String): RefereeMatchEntity?

    @Query("SELECT * FROM referee_matches WHERE status IN ('completed', 'abandoned') ORDER BY updatedAt DESC")
    suspend fun completedAndAbandoned(): List<RefereeMatchEntity>

    @Query("SELECT * FROM referee_games WHERE matchId = :matchId ORDER BY number ASC")
    suspend fun gamesForMatch(matchId: String): List<RefereeGameEntity>

    @Query("SELECT * FROM referee_points WHERE gameId = :gameId ORDER BY pointNumber ASC")
    suspend fun pointsForGame(gameId: String): List<RefereePointEntity>

    @Query("SELECT * FROM referee_current_points WHERE matchId = :matchId ORDER BY pointNumber ASC")
    suspend fun currentPointsForMatch(matchId: String): List<RefereeCurrentPointEntity>

    @Query("DELETE FROM referee_matches WHERE id = :id")
    suspend fun deleteMatchById(id: String)

    @Query("DELETE FROM referee_matches")
    suspend fun deleteAll()

    /**
     * Replaces a match's own row, its completed games/points and the current
     * game's in-progress rally history in one transaction. Mirrors
     * `MatchDao.upsertMatchWithChildren`: children are always fully replaced
     * rather than diffed.
     */
    @Transaction
    suspend fun upsertMatchWithChildren(
        match: RefereeMatchEntity,
        games: List<RefereeGameEntity>,
        points: List<RefereePointEntity>,
        currentPoints: List<RefereeCurrentPointEntity>,
    ) {
        insertMatch(match.copy(savedAt = matchById(match.id)?.savedAt ?: match.savedAt))
        deleteGamesForMatch(match.id) // cascades to points for the old games
        if (games.isNotEmpty()) insertGames(games)
        if (points.isNotEmpty()) insertPoints(points)
        deleteCurrentPointsForMatch(match.id)
        if (currentPoints.isNotEmpty()) insertCurrentPoints(currentPoints)
    }
}
