package com.squashanalyzer.android.team

import androidx.room.withTransaction
import com.squashanalyzer.android.data.AppDatabase
import com.squashanalyzer.android.data.PlayerEntity
import org.json.JSONArray
import skip.foundation.Data
import skip.lib.Array as SwiftArray
import squash.analyzer.core.TeamDownloader
import squash.analyzer.core.TeamImport
import squash.analyzer.core.TeamImportEntry
import squash.analyzer.core.TeamImportError
import squash.analyzer.core.TeamImportResult
import squash.analyzer.core.TeamLinkImporter
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.UUID
import java.util.zip.ZipInputStream

/**
 * Android's team import (Spelers → Team via link), the counterpart of iOS'
 * `TeamImportService`: the checks come from Core's `TeamImport`; this class
 * unzips, scales photos with `PhotoScaler` (like iOS' `PlayerPhoto`), and
 * writes Room in one transaction after every player and photo was checked.
 */
class RoomTeamImporter(
    private val db: AppDatabase,
    private val downloader: TeamDownloader = HttpTeamDownloader(),
) : TeamLinkImporter {

    override suspend fun importTeam(link: String): TeamImportResult {
        val url = TeamImport.link(from = link) ?: throw TeamImportError.invalidLink
        val zip = try {
            downloader.download(url)
        } catch (error: TeamImportError) {
            throw error
        } catch (error: Exception) {
            throw TeamImportError.unavailable
        }
        return importZip(zip.platformValue)
    }

    override suspend fun importTeam(zip: Data): TeamImportResult = importZip(zip.platformValue)

    suspend fun importZip(bytes: ByteArray): TeamImportResult {
        val files = unzip(bytes)
        val jsonPath = TeamImport.teamJSONPath(in_ = SwiftArray(files.keys.toList())) ?: throw TeamImportError.missingTeamJSON
        val file = TeamImport.decode(Data(platformValue = files.getValue(jsonPath)))
        val base = TeamImport.baseDirectory(ofTeamJSON = jsonPath)

        val prepared = TeamImport.entries(of = file).toList().map { entry ->
            val photo = entry.photoPath?.let { path ->
                val raw = files[base + path] ?: files[path] ?: throw TeamImportError.photoNotFound(player = entry.name, path = path)
                PhotoScaler.squareJpeg(raw) ?: throw TeamImportError.photoUnreadable(player = entry.name, path = path)
            }
            entry to photo
        }

        var added = 0
        var updated = 0
        var photos = 0
        db.withTransaction {
            val existing = db.playerDao().all()
            for ((entry, photo) in prepared) {
                val index = TeamImport.matchIndex(for_ = entry, in_ = SwiftArray(existing.map { it.name }))
                if (index != null) {
                    val match = existing[index]
                    db.playerDao().updateFields(
                        match.id, match.name,
                        if (entry.focus.isEmpty) match.coachingFocusAreas else focusJson(entry),
                        entry.notes ?: match.coachingNotes,
                    )
                    if (photo != null) db.playerDao().setPhoto(match.id, photo)
                    updated++
                } else {
                    db.playerDao().insert(PlayerEntity(
                        id = UUID.randomUUID().toString().uppercase(), name = entry.name,
                        coachingFocusAreas = focusJson(entry), coachingNotes = entry.notes ?: "",
                        createdAt = System.currentTimeMillis() / 1000.0, photoData = photo,
                    ))
                    added++
                }
                if (photo != null) photos++
            }
        }
        return TeamImportResult(team = file.team, added = added, updated = updated, photos = photos)
    }

    private fun focusJson(entry: TeamImportEntry): String = JSONArray().apply { entry.focus.forEach { put(it) } }.toString()

    /** Every file in the zip by path, without folders and macOS "__MACOSX" leftovers */
    private fun unzip(bytes: ByteArray): Map<String, ByteArray> {
        val files = mutableMapOf<String, ByteArray>()
        var total = 0L
        try {
            ZipInputStream(ByteArrayInputStream(bytes)).use { zip ->
                while (true) {
                    val entry = zip.nextEntry ?: break
                    if (entry.isDirectory || entry.name.startsWith("__MACOSX/") || entry.name.contains("/._")) continue
                    val content = zip.readBytes()
                    total += content.size
                    if (total > TeamImport.maxBytes * 2L) throw TeamImportError.tooLarge
                    files[entry.name] = content
                }
            }
        } catch (error: TeamImportError) {
            throw error
        } catch (error: Exception) {
            throw TeamImportError.notAZip
        }
        if (files.isEmpty()) throw TeamImportError.notAZip
        return files
    }
}
