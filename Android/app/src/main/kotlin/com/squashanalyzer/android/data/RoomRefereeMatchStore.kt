package com.squashanalyzer.android.data

import skip.foundation.Date
import skip.foundation.UUID
import skip.lib.Array as SwiftArray
import squash.analyzer.core.*

/** Maps the shared live `RefereeMatch` model to a transactional Room store. */
class RoomRefereeMatchStore(
    private val store: RefereeMatchStore,
    private val badgeAwardStore: BadgeAwardStore,
) : squash.analyzer.core.RefereeMatchStore {
    override suspend fun loadInProgress(): RefereeMatch? = store.mostRecentInProgressMatch()?.let(::restore)

    override suspend fun save(match: RefereeMatch) {
        // Capture the entire mutable model before the first suspension. The UI
        // serializes edits; Room's upsert replaces all children atomically.
        val snapshot = capture(match)
        store.upsert(snapshot)
        syncBadges(match)
    }

    override suspend fun abandon(match: RefereeMatch) {
        store.upsert(capture(match).copy(status = MatchStatus.ABANDONED))
        syncBadges(match)
    }

    /** A saved match by id, as the live model (Afgeronde wedstrijden) */
    suspend fun byId(id: String): RefereeMatch? = store.byId(id)?.let(::restore)

    /** Only players picked via "Kies speler" (a real id) ever earn a badge. */
    private suspend fun syncBadges(match: RefereeMatch) {
        val players = buildList {
            match.player1Id?.let { add(it.uuidString to Player.player1) }
            match.player2Id?.let { add(it.uuidString to Player.player2) }
        }
        if (players.isEmpty()) return
        badgeAwardStore.syncAwards(match.id.uuidString, players,
            mapOf(Player.player1 to match.player1Name, Player.player2 to match.player2Name), match.badgeInput)
    }

    private fun capture(match: RefereeMatch): RefereeMatchRecord {
        val now = System.currentTimeMillis()
        return RefereeMatchRecord(
            id = match.id.uuidString, player1Name = match.player1Name, player2Name = match.player2Name,
            player1Id = match.player1Id?.uuidString, player2Id = match.player2Id?.uuidString,
            bestOf = match.bestOf,
            player1GamesBefore = match.player1GamesBefore, player2GamesBefore = match.player2GamesBefore,
            player1Score = match.player1Score, player2Score = match.player2Score,
            currentServer = match.currentServer.rawValue, serverSide = match.serverSide.rawValue,
            currentGameNumber = match.currentGameNumber,
            player1PreferredSide = match.player1PreferredSide?.rawValue,
            player2PreferredSide = match.player2PreferredSide?.rawValue,
            openingServer = match.openingServer?.rawValue, openingSide = match.openingSide?.rawValue,
            matchStartedAt = millis(match.matchStartedAt), gameStartedAt = millis(match.gameStartedAt),
            lastPointAt = match.lastPointAt?.let(::millis),
            savedAt = now, updatedAt = now,
            status = if (match.isMatchOver) MatchStatus.COMPLETED else MatchStatus.IN_PROGRESS,
            completedGames = match.completedGames.mapIndexed { _, game ->
                RefereeGameRecord(
                    id = game.id.uuidString, number = game.number,
                    player1Score = game.player1Score, player2Score = game.player2Score,
                    winner = game.winner.rawValue, duration = game.duration ?: 0.0,
                    points = game.points.mapIndexed { i, point ->
                        RefereePointRecord(point.id.uuidString, i + 1, point.scorer.rawValue, point.score, point.side.rawValue, point.isStroke)
                    }
                )
            },
            currentPoints = match.pointHistory.mapIndexed { i, point ->
                RefereePointRecord(point.id.uuidString, i + 1, point.scorer.rawValue, point.score, point.side.rawValue, point.isStroke)
            }
        )
    }

    private fun restore(row: RefereeMatchRecord): RefereeMatch {
        val match = RefereeMatch(
            id = uuid(row.id), player1Name = row.player1Name, player2Name = row.player2Name,
            bestOf = row.bestOf, startingServer = player(row.currentServer),
            player1GamesBefore = row.player1GamesBefore, player2GamesBefore = row.player2GamesBefore,
        )
        match.player1Id = row.player1Id?.let(::uuid)
        match.player2Id = row.player2Id?.let(::uuid)
        match.player1Score = row.player1Score
        match.player2Score = row.player2Score
        match.currentServer = player(row.currentServer)
        match.serverSide = requireNotNull(ServerSide.init(rawValue = row.serverSide))
        match.currentGameNumber = row.currentGameNumber
        match.player1PreferredSide = row.player1PreferredSide?.let { requireNotNull(ServerSide.init(rawValue = it)) }
        match.player2PreferredSide = row.player2PreferredSide?.let { requireNotNull(ServerSide.init(rawValue = it)) }
        match.openingServer = row.openingServer?.let(::player)
        match.openingSide = row.openingSide?.let { requireNotNull(ServerSide.init(rawValue = it)) }
        match.gameStartedAt = date(row.gameStartedAt)
        // Time spent with the app closed is not part of the next rally.
        match.lastPointAt = row.currentPoints.lastOrNull()?.let { Date() }
        match.completedGames = SwiftArray(row.completedGames.map { saved ->
            CompletedRefereeGame(
                id = uuid(saved.id), number = saved.number,
                player1Score = saved.player1Score, player2Score = saved.player2Score,
                winner = player(saved.winner), duration = saved.duration,
                points = SwiftArray(saved.points.map { point ->
                    RefereePointEntry(id = uuid(point.id), scorer = player(point.scorer), score = point.score,
                        side = requireNotNull(ServerSide.init(rawValue = point.side)), isStroke = point.isStroke)
                })
            )
        })
        match.pointHistory = SwiftArray(row.currentPoints.map { point ->
            RefereePointEntry(id = uuid(point.id), scorer = player(point.scorer), score = point.score,
                side = requireNotNull(ServerSide.init(rawValue = point.side)), isStroke = point.isStroke)
        })
        // Undo works again for every rally of this game
        match.rebuildUndo()
        return match
    }

    private fun uuid(value: String): UUID = requireNotNull(UUID(uuidString = value))
    private fun player(value: String): Player = requireNotNull(Player.init(rawValue = value))
    private fun date(millis: Long) = Date(timeIntervalSince1970 = millis.toDouble() / 1000.0)
    private fun millis(date: Date) = (date.timeIntervalSince1970 * 1000.0).toLong()
}
