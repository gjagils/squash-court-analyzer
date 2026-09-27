package com.squashanalyzer.android.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction

@Dao
interface BadgeAwardDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(awards: List<BadgeAwardEntity>)

    @Query("SELECT * FROM badge_awards WHERE matchId = :matchId")
    suspend fun forMatch(matchId: String): List<BadgeAwardEntity>

    @Query("UPDATE badge_awards SET deletedAt = :deletedAt WHERE id = :id")
    suspend fun markDeleted(id: String, deletedAt: Long)

    @Query("SELECT * FROM badge_awards WHERE playerId = :playerId AND deletedAt IS NULL")
    suspend fun activeForPlayer(playerId: String): List<BadgeAwardEntity>

    @Query("DELETE FROM badge_awards WHERE matchId = :matchId")
    suspend fun deleteForMatch(matchId: String)

    /**
     * Replaces this match's award rows with exactly the currently-earned set:
     * inserts/refreshes `current` (an `OnConflictStrategy.REPLACE` upsert also
     * un-deletes a badge re-earned after an undo-then-redo), then soft-deletes
     * any of the match's existing rows that are no longer in `currentIds` —
     * mirrors "an undone rally takes back an award" from `BadgeAwarder`.
     */
    @Transaction
    suspend fun replaceForMatch(matchId: String, current: List<BadgeAwardEntity>, currentIds: Set<String>) {
        if (current.isNotEmpty()) insertAll(current)
        val now = System.currentTimeMillis()
        forMatch(matchId).forEach { row ->
            if (row.id !in currentIds && row.deletedAt == null) markDeleted(row.id, now)
        }
    }
}
