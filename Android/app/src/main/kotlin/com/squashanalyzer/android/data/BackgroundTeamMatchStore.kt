package com.squashanalyzer.android.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import skip.foundation.URL
import skip.foundation.UUID
import skip.lib.Array as SwiftArray
import squash.analyzer.core.TeamMatch
import squash.analyzer.core.TeamMatchFile
import squash.analyzer.core.TeamMatchStore

/**
 * Competitie's team matches in Core's JSON file, read and written on
 * Dispatchers.IO instead of the main thread. One request at a time, so two
 * quick saves cannot overwrite each other (iOS: `BackgroundTeamMatchStore`).
 */
class BackgroundTeamMatchStore(private val directory: URL) : TeamMatchStore {
    private val lock = Mutex()

    override suspend fun loadAll(): SwiftArray<TeamMatch> = io { TeamMatchFile.newestFirst(directory = directory) }

    override suspend fun save(match: TeamMatch) = io { TeamMatchFile.upsert(match, directory = directory) }

    override suspend fun delete(id: UUID) = io { TeamMatchFile.remove(id = id, directory = directory) }

    private suspend fun <T> io(block: () -> T): T = lock.withLock { withContext(Dispatchers.IO) { block() } }
}
