package com.squashanalyzer.android.data

/**
 * Android counterpart of the (Android-only, not yet ported) referee-match
 * persistence: same "replace all child records" write strategy as
 * `MatchStore`, backed by Room/SQLite. Only `RefereeMatch`'s data moves here.
 */
class RefereeMatchStore(private val dao: RefereeMatchDao) {

    suspend fun upsert(match: RefereeMatchRecord) {
        val entity = RefereeMatchEntity(
            id = match.id,
            player1Name = match.player1Name,
            player2Name = match.player2Name,
            player1Id = match.player1Id,
            player2Id = match.player2Id,
            bestOf = match.bestOf,
            player1GamesBefore = match.player1GamesBefore,
            player2GamesBefore = match.player2GamesBefore,
            player1Score = match.player1Score,
            player2Score = match.player2Score,
            currentServer = match.currentServer,
            serverSide = match.serverSide,
            currentGameNumber = match.currentGameNumber,
            player1PreferredSide = match.player1PreferredSide,
            player2PreferredSide = match.player2PreferredSide,
            matchStartedAt = match.matchStartedAt,
            gameStartedAt = match.gameStartedAt,
            lastPointAt = match.lastPointAt,
            savedAt = match.savedAt,
            updatedAt = match.updatedAt,
            status = match.status,
        )
        val games = match.completedGames.map { game ->
            RefereeGameEntity(
                id = game.id,
                matchId = match.id,
                number = game.number,
                player1Score = game.player1Score,
                player2Score = game.player2Score,
                winner = game.winner,
                duration = game.duration,
            )
        }
        val points = match.completedGames.flatMap { game ->
            game.points.map { point ->
                RefereePointEntity(
                    id = point.id,
                    gameId = game.id,
                    pointNumber = point.pointNumber,
                    scorer = point.scorer,
                    score = point.score,
                    side = point.side,
                    isStroke = point.isStroke,
                )
            }
        }
        val currentPoints = match.currentPoints.map { point ->
            RefereeCurrentPointEntity(
                id = point.id,
                matchId = match.id,
                pointNumber = point.pointNumber,
                scorer = point.scorer,
                score = point.score,
                side = point.side,
                isStroke = point.isStroke,
            )
        }
        dao.upsertMatchWithChildren(entity, games, points, currentPoints)
    }

    suspend fun history(): List<RefereeMatchRecord> = dao.completedAndAbandoned().map { assemble(it) }

    suspend fun mostRecentInProgressMatch(): RefereeMatchRecord? =
        dao.mostRecentMatchWithStatus(MatchStatus.IN_PROGRESS)?.let { assemble(it) }

    suspend fun delete(match: RefereeMatchRecord) {
        dao.deleteMatchById(match.id)
    }

    private suspend fun assemble(entity: RefereeMatchEntity): RefereeMatchRecord {
        val games = dao.gamesForMatch(entity.id).map { game ->
            RefereeGameRecord(
                id = game.id,
                number = game.number,
                player1Score = game.player1Score,
                player2Score = game.player2Score,
                winner = game.winner,
                duration = game.duration,
                points = dao.pointsForGame(game.id).map {
                    RefereePointRecord(
                        id = it.id,
                        pointNumber = it.pointNumber,
                        scorer = it.scorer,
                        score = it.score,
                        side = it.side,
                        isStroke = it.isStroke,
                    )
                },
            )
        }
        val currentPoints = dao.currentPointsForMatch(entity.id).map {
            RefereePointRecord(
                id = it.id,
                pointNumber = it.pointNumber,
                scorer = it.scorer,
                score = it.score,
                side = it.side,
                isStroke = it.isStroke,
            )
        }
        return RefereeMatchRecord(
            id = entity.id,
            player1Name = entity.player1Name,
            player2Name = entity.player2Name,
            player1Id = entity.player1Id,
            player2Id = entity.player2Id,
            bestOf = entity.bestOf,
            player1GamesBefore = entity.player1GamesBefore,
            player2GamesBefore = entity.player2GamesBefore,
            player1Score = entity.player1Score,
            player2Score = entity.player2Score,
            currentServer = entity.currentServer,
            serverSide = entity.serverSide,
            currentGameNumber = entity.currentGameNumber,
            player1PreferredSide = entity.player1PreferredSide,
            player2PreferredSide = entity.player2PreferredSide,
            matchStartedAt = entity.matchStartedAt,
            gameStartedAt = entity.gameStartedAt,
            lastPointAt = entity.lastPointAt,
            savedAt = entity.savedAt,
            updatedAt = entity.updatedAt,
            status = entity.status,
            completedGames = games,
            currentPoints = currentPoints,
        )
    }
}
