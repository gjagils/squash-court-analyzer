package com.squashanalyzer.android.data

import org.json.JSONArray
import skip.lib.Array as SwiftArray
import squash.analyzer.core.PlayerProfile
import squash.analyzer.core.PlayerPhotoStore
import squash.analyzer.core.PlayerProfileStore
import com.squashanalyzer.android.team.PhotoScaler
import skip.foundation.Data
import skip.lib.Dictionary

/** Room implements the protocol generated from Swift; UI has no Room dependency. */
class RoomPlayerStore(private val dao: PlayerDao) : PlayerProfileStore, PlayerPhotoStore {
    override suspend fun loadPlayers(): SwiftArray<PlayerProfile> = SwiftArray(dao.all().map { row ->
        val json = JSONArray(row.coachingFocusAreas)
        PlayerProfile(
            id = row.id,
            name = row.name,
            coachingFocusAreas = SwiftArray((0 until json.length()).map { json.getString(it) }),
            coachingNotes = row.coachingNotes,
            createdAt = row.createdAt,
        )
    })

    override suspend fun savePlayer(player: PlayerProfile) {
        require(player.isValid) { "Een speler moet een naam hebben." }
        val focus = JSONArray()
        player.coachingFocusAreas.forEach { focus.put(it) }
        dao.save(PlayerEntity(
            id = player.id,
            name = player.trimmedName,
            coachingFocusAreas = focus.toString(),
            coachingNotes = player.coachingNotes,
            createdAt = player.createdAt,
        ))
    }

    override suspend fun deletePlayer(id: String) = dao.delete(id)

    override suspend fun photos(): Dictionary<String, Data> {
        val result = Dictionary<String, Data>()
        for (row in dao.all()) {
            row.photoData?.let { result[row.id] = Data(platformValue = it) }
        }
        return result
    }

    override suspend fun setPhoto(image: Data?, playerId: String) {
        if (image == null) {
            dao.clearPhoto(playerId)
            return
        }
        val scaled = requireNotNull(PhotoScaler.squareJpeg(image.platformValue)) { "Dit is geen bruikbare foto." }
        dao.setPhoto(playerId, scaled)
    }
}
