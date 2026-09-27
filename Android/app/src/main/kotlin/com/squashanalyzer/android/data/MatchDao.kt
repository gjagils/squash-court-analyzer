package com.squashanalyzer.android.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction

@Dao
interface MatchDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMatch(match: MatchEntity)

    @Query("DELETE FROM games WHERE matchId = :matchId")
    suspend fun deleteGamesForMatch(matchId: String)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertGames(games: List<GameEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPoints(points: List<PointEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLets(lets: List<LetEntity>)

    @Query("SELECT * FROM matches WHERE id = :id LIMIT 1")
    suspend fun matchById(id: String): MatchEntity?

    @Query("SELECT * FROM matches WHERE status = :status ORDER BY updatedAt DESC LIMIT 1")
    suspend fun mostRecentMatchWithStatus(status: String): MatchEntity?

    @Query("SELECT * FROM games WHERE matchId = :matchId ORDER BY gameNumber ASC")
    suspend fun gamesForMatch(matchId: String): List<GameEntity>

    @Query("SELECT * FROM points WHERE gameId = :gameId ORDER BY pointNumber ASC")
    suspend fun pointsForGame(gameId: String): List<PointEntity>

    @Query("SELECT * FROM lets WHERE gameId = :gameId ORDER BY letNumber ASC")
    suspend fun letsForGame(gameId: String): List<LetEntity>

    @Query("DELETE FROM matches WHERE id = :id")
    suspend fun deleteMatchById(id: String)

    /**
     * Replaces a match's own row and all of its child games/points/lets in
     * one transaction. Mirrors `SwiftDataMatchRepository.upsert`: children are
     * always fully replaced rather than diffed, since a match holds few
     * records and this keeps the write path simple.
     */
    @Transaction
    suspend fun upsertMatchWithChildren(match: MatchEntity, games: List<GameEntity>, points: List<PointEntity>, lets: List<LetEntity>) {
        insertMatch(match.copy(savedAt = matchById(match.id)?.savedAt ?: match.savedAt))
        deleteGamesForMatch(match.id) // cascades to points/lets for the old games
        if (games.isNotEmpty()) insertGames(games)
        if (points.isNotEmpty()) insertPoints(points)
        if (lets.isNotEmpty()) insertLets(lets)
    }
}
