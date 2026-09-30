package com.squashanalyzer.android.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction

@Dao
interface BadgeAwardDao {
    /** Existing ids are left alone, so a deleted award is never brought back. */
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertAll(awards: List<BadgeAwardEntity>)

    @Query("SELECT * FROM badge_awards WHERE matchId = :matchId")
    suspend fun forMatch(matchId: String): List<BadgeAwardEntity>

    @Query("SELECT * FROM badge_awards WHERE cardId = :cardId")
    suspend fun forCard(cardId: String): List<BadgeAwardEntity>

    @Query("SELECT * FROM badge_awards WHERE cardId = :cardId AND deletedAt IS NULL")
    suspend fun activeForCard(cardId: String): List<BadgeAwardEntity>

    @Query("SELECT * FROM badge_awards WHERE id = :id")
    suspend fun byId(id: String): BadgeAwardEntity?

    @Query("UPDATE badge_awards SET deletedAt = :deletedAt WHERE id = :id")
    suspend fun markDeleted(id: String, deletedAt: Long)

    @Query("DELETE FROM badge_awards WHERE id IN (:ids)")
    suspend fun deleteByIds(ids: List<String>)

    @Query("DELETE FROM badge_awards WHERE matchId = :matchId")
    suspend fun deleteForMatch(matchId: String)

    /**
     * Brings one match's awards in line with what its rallies earn, exactly
     * like iOS' `BadgeAwarder.syncAwards`: an active award the rallies no
     * longer support is removed outright (an undone rally never really earned
     * it), a missing one is inserted, and a deleted one stays deleted.
     */
    @Transaction
    suspend fun syncMatch(matchId: String, expected: List<BadgeAwardEntity>) {
        val expectedIds = expected.map { it.id }.toSet()
        val retracted = forMatch(matchId).filter { it.deletedAt == null && it.id !in expectedIds }.map { it.id }
        if (retracted.isNotEmpty()) deleteByIds(retracted)
        if (expected.isNotEmpty()) insertAll(expected)
    }
}
