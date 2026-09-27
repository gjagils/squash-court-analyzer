package com.squashanalyzer.android.data

import org.json.JSONArray

/**
 * Android counterpart of iOS's `MatchRepository`/`SwiftDataMatchRepository`
 * (SquashAnalyzer/Services/MatchRepository.swift): same four operations, same
 * "replace all child records" write strategy, backed by Room/SQLite instead
 * of SwiftData. There is no shared Swift protocol here — SwiftData does not
 * transpile to Android, so this side is plain, hand-written Kotlin that keeps
 * the same shape by convention. Only `Match`/`Game`/`Point`/`LetCall`'s data
 * moved here (badges, players and referee matches are not part of phase 3).
 */
class MatchStore(private val dao: MatchDao) {

    suspend fun upsert(match: MatchRecord) {
        val entity = MatchEntity(
            id = match.id,
            player1Name = match.player1Name,
            player2Name = match.player2Name,
            matchStartingServer = match.matchStartingServer,
            bestOf = match.bestOf,
            savedAt = match.savedAt,
            updatedAt = match.updatedAt,
            status = match.status,
            player1CoachingFocus = encodeStrings(match.player1CoachingFocus),
            player2CoachingFocus = encodeStrings(match.player2CoachingFocus),
            player1CoachingNotes = match.player1CoachingNotes,
            player2CoachingNotes = match.player2CoachingNotes,
            player1GamesBefore = match.player1GamesBefore,
            player2GamesBefore = match.player2GamesBefore,
            player1GamesAfter = match.player1GamesAfter,
            player2GamesAfter = match.player2GamesAfter,
            player1Id = match.player1Id,
            player2Id = match.player2Id,
        )
        val games = match.games.map { game ->
            GameEntity(
                id = game.id,
                matchId = match.id,
                gameNumber = game.gameNumber,
                player1Name = game.player1Name,
                player2Name = game.player2Name,
                player1Score = game.player1Score,
                player2Score = game.player2Score,
                startingServer = game.startingServer,
                winner = game.winner,
                savedAt = game.savedAt,
                serviceState = game.serviceState,
            )
        }
        val points = match.games.flatMap { game ->
            game.points.map { point ->
                PointEntity(
                    id = point.id,
                    gameId = game.id,
                    pointNumber = point.pointNumber,
                    scorer = point.scorer,
                    pointType = point.pointType,
                    zone = point.zone,
                    shotType = point.shotType,
                    server = point.server,
                    player1Score = point.player1Score,
                    player2Score = point.player2Score,
                    timestamp = point.timestamp,
                    duration = point.duration,
                )
            }
        }
        val lets = match.games.flatMap { game ->
            game.lets.map { letCall ->
                LetEntity(
                    id = letCall.id,
                    gameId = game.id,
                    letNumber = letCall.letNumber,
                    requestedBy = letCall.requestedBy,
                    server = letCall.server,
                    player1Score = letCall.player1Score,
                    player2Score = letCall.player2Score,
                    timestamp = letCall.timestamp,
                )
            }
        }
        dao.upsertMatchWithChildren(entity, games, points, lets)
    }

    suspend fun history(): List<MatchRecord> = dao.completedAndAbandoned().map { assemble(it) }

    suspend fun mostRecentInProgressMatch(): MatchRecord? =
        dao.mostRecentMatchWithStatus(MatchStatus.IN_PROGRESS)?.let { assemble(it) }

    suspend fun markAbandoned(match: MatchRecord) {
        upsert(match.copy(status = MatchStatus.ABANDONED))
    }

    suspend fun delete(match: MatchRecord) {
        dao.deleteMatchById(match.id)
    }

    private suspend fun assemble(entity: MatchEntity): MatchRecord {
        val games = dao.gamesForMatch(entity.id).map { game ->
            GameRecord(
                id = game.id,
                gameNumber = game.gameNumber,
                player1Name = game.player1Name,
                player2Name = game.player2Name,
                player1Score = game.player1Score,
                player2Score = game.player2Score,
                startingServer = game.startingServer,
                winner = game.winner,
                savedAt = game.savedAt,
                serviceState = game.serviceState,
                points = dao.pointsForGame(game.id).map {
                    PointRecord(
                        id = it.id,
                        pointNumber = it.pointNumber,
                        scorer = it.scorer,
                        pointType = it.pointType,
                        zone = it.zone,
                        shotType = it.shotType,
                        server = it.server,
                        player1Score = it.player1Score,
                        player2Score = it.player2Score,
                        timestamp = it.timestamp,
                        duration = it.duration,
                    )
                },
                lets = dao.letsForGame(game.id).map {
                    LetRecord(
                        id = it.id,
                        letNumber = it.letNumber,
                        requestedBy = it.requestedBy,
                        server = it.server,
                        player1Score = it.player1Score,
                        player2Score = it.player2Score,
                        timestamp = it.timestamp,
                    )
                },
            )
        }
        return MatchRecord(
            id = entity.id,
            player1Name = entity.player1Name,
            player2Name = entity.player2Name,
            matchStartingServer = entity.matchStartingServer,
            bestOf = entity.bestOf,
            savedAt = entity.savedAt,
            updatedAt = entity.updatedAt,
            status = entity.status,
            player1CoachingFocus = decodeStrings(entity.player1CoachingFocus),
            player2CoachingFocus = decodeStrings(entity.player2CoachingFocus),
            player1CoachingNotes = entity.player1CoachingNotes,
            player2CoachingNotes = entity.player2CoachingNotes,
            player1GamesBefore = entity.player1GamesBefore,
            player2GamesBefore = entity.player2GamesBefore,
            player1GamesAfter = entity.player1GamesAfter,
            player2GamesAfter = entity.player2GamesAfter,
            player1Id = entity.player1Id,
            player2Id = entity.player2Id,
            games = games,
        )
    }

    private fun encodeStrings(values: List<String>): String {
        val array = JSONArray()
        values.forEach { array.put(it) }
        return array.toString()
    }

    private fun decodeStrings(json: String): List<String> {
        if (json.isEmpty()) return emptyList()
        val array = JSONArray(json)
        return (0 until array.length()).map { array.getString(it) }
    }
}
