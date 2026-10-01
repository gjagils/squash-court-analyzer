package com.squashanalyzer.android.data

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Transaction

@Entity(tableName = "players")
data class PlayerEntity(
    @PrimaryKey val id: String,
    val name: String,
    val coachingFocusAreas: String,
    val coachingNotes: String,
    val createdAt: Double,
    val photoData: ByteArray? = null,
    val cardId: String? = null,
)

@Dao
abstract class PlayerDao {
    @Query("SELECT * FROM players ORDER BY name COLLATE NOCASE, id")
    abstract suspend fun all(): List<PlayerEntity>

    @Query("SELECT * FROM players WHERE id = :id")
    abstract suspend fun byId(id: String): PlayerEntity?

    @Insert
    abstract suspend fun insert(player: PlayerEntity)

    @Query("UPDATE players SET name = :name, coachingFocusAreas = :focus, coachingNotes = :notes WHERE id = :id")
    abstract suspend fun updateFields(id: String, name: String, focus: String, notes: String)

    @Transaction
    open suspend fun save(player: PlayerEntity) {
        if (byId(player.id) == null) insert(player)
        else updateFields(player.id, player.name, player.coachingFocusAreas, player.coachingNotes)
    }

    /** Links the player to a shared card; null means the card is the player's own id */
    @Query("UPDATE players SET photoData = :photo WHERE id = :id")
    abstract suspend fun setPhoto(id: String, photo: ByteArray)

    @Query("UPDATE players SET cardId = :cardId WHERE id = :id")
    abstract suspend fun setCardId(id: String, cardId: String?)

    // Deliberately no foreign key from match history to this editable directory.
    @Query("DELETE FROM players")
    abstract suspend fun deleteAll()

    @Query("DELETE FROM players WHERE id = :id")
    abstract suspend fun delete(id: String)
}
