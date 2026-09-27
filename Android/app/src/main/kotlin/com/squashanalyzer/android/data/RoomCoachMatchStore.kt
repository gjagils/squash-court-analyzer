package com.squashanalyzer.android.data

import org.json.JSONObject
import skip.foundation.Date
import skip.foundation.UUID
import skip.lib.Array as SwiftArray
import squash.analyzer.core.*
import squash.analyzer.core.MatchStatus as CoreStatus

/** Maps the shared live model to phase 3's transactional Room MatchStore. */
class RoomCoachMatchStore(private val store: MatchStore) : CoachMatchStore {
    override suspend fun loadInProgress(): Match? = store.mostRecentInProgressMatch()?.let(::restore)

    override suspend fun save(match: Match) {
        // Capture the entire mutable model before the first suspension. The UI
        // serializes edits; Room's upsert replaces all children atomically.
        val snapshot = capture(match)
        store.upsert(snapshot)
        match.status = CoreStatus.init(rawValue = snapshot.status)!!
        match.updatedAt = date(snapshot.updatedAt)
    }

    override suspend fun abandon(match: Match) {
        val snapshot = capture(match).copy(status = MatchStatus.ABANDONED)
        store.upsert(snapshot)
        match.status = CoreStatus.abandoned
    }

    private fun capture(match: Match): MatchRecord {
        val now = System.currentTimeMillis()
        return MatchRecord(
            id = match.id.uuidString, player1Name = match.player1Name, player2Name = match.player2Name,
            matchStartingServer = match.matchStartingServer.rawValue, bestOf = match.bestOf,
            savedAt = millis(match.updatedAt), updatedAt = now,
            status = if (match.isMatchOver) MatchStatus.COMPLETED else match.status.rawValue,
            player1CoachingFocus = match.player1CoachingFocus.toList(),
            player2CoachingFocus = match.player2CoachingFocus.toList(),
            player1CoachingNotes = match.player1CoachingNotes, player2CoachingNotes = match.player2CoachingNotes,
            player1GamesBefore = match.player1GamesBefore, player2GamesBefore = match.player2GamesBefore,
            player1GamesAfter = match.player1GamesAfter, player2GamesAfter = match.player2GamesAfter,
            player1Id = match.player1Id?.uuidString, player2Id = match.player2Id?.uuidString,
            games = match.games.mapIndexed { index, game ->
                GameRecord(
                    id = game.id.uuidString, gameNumber = match.gameNumber(at = index),
                    player1Name = game.player1Name, player2Name = game.player2Name,
                    player1Score = game.player1Score, player2Score = game.player2Score,
                    startingServer = game.startingServer.rawValue, winner = game.winner?.rawValue, savedAt = now,
                    serviceState = JSONObject().apply {
                        put("side", game.serverSide.rawValue)
                        put("player1Preferred", game.player1PreferredSide?.rawValue ?: JSONObject.NULL)
                        put("player2Preferred", game.player2PreferredSide?.rawValue ?: JSONObject.NULL)
                    }.toString(),
                    points = game.points.mapIndexed { i, point ->
                        PointRecord(point.id.uuidString, i + 1, point.scorer.rawValue, point.pointType.rawValue,
                            point.zone?.rawValue ?: "", point.shotType?.rawValue ?: "", point.server.rawValue,
                            point.player1Score, point.player2Score, millis(point.timestamp), point.duration)
                    },
                    lets = game.lets.mapIndexed { i, call ->
                        LetRecord(call.id.uuidString, i + 1, call.requestedBy.rawValue, call.server.rawValue,
                            call.player1Score, call.player2Score, millis(call.timestamp))
                    }
                )
            }
        )
    }

    private fun restore(row: MatchRecord): Match {
        require(row.bestOf == 5) { "Unsupported match format" }
        val match = Match(id = uuid(row.id))
        match.player1Name = row.player1Name
        match.player2Name = row.player2Name
        match.matchStartingServer = player(row.matchStartingServer)
        match.player1CoachingFocus = SwiftArray(row.player1CoachingFocus)
        match.player2CoachingFocus = SwiftArray(row.player2CoachingFocus)
        match.player1CoachingNotes = row.player1CoachingNotes
        match.player2CoachingNotes = row.player2CoachingNotes
        match.player1GamesBefore = row.player1GamesBefore
        match.player2GamesBefore = row.player2GamesBefore
        match.player1GamesAfter = row.player1GamesAfter
        match.player2GamesAfter = row.player2GamesAfter
        match.player1Id = row.player1Id?.let(::uuid)
        match.player2Id = row.player2Id?.let(::uuid)
        require(row.games.isNotEmpty()) { "Saved match has no games" }
        match.games = SwiftArray(row.games.map { saved ->
            val game = Game(id = uuid(saved.id))
            game.player1Name = saved.player1Name
            game.player2Name = saved.player2Name
            game.startingServer = player(saved.startingServer)
            game.player1Score = saved.player1Score
            game.player2Score = saved.player2Score
            game.points = SwiftArray(saved.points.map { point ->
                Point(id = uuid(point.id), scorer = player(point.scorer),
                    pointType = requireNotNull(PointType.init(rawValue = point.pointType)),
                    zone = if (point.zone.isEmpty()) null else requireNotNull(CourtZone.init(rawValue = point.zone)),
                    shotType = if (point.shotType.isEmpty()) null else requireNotNull(ShotType.init(rawValue = point.shotType)),
                    server = player(point.server), player1Score = point.player1Score, player2Score = point.player2Score,
                    timestamp = date(point.timestamp), duration = point.duration)
            })
            game.lets = SwiftArray(saved.lets.map { call ->
                LetCall(id = uuid(call.id), requestedBy = player(call.requestedBy), server = player(call.server),
                    player1Score = call.player1Score, player2Score = call.player2Score, timestamp = date(call.timestamp))
            })
            saved.serviceState?.let { json ->
                val state = JSONObject(json)
                game.player1PreferredSide = ServerSide.init(rawValue = state.optString("player1Preferred"))
                game.player2PreferredSide = ServerSide.init(rawValue = state.optString("player2Preferred"))
            }
            game.restoreServiceState()
            saved.serviceState?.let { game.serverSide = requireNotNull(ServerSide.init(rawValue = JSONObject(it).getString("side"))) }
            // Time spent with the app closed is not part of the next rally.
            game.lastPointTime = Date()
            game
        })
        match.currentGameIndex = row.games.lastIndex
        match.status = requireNotNull(CoreStatus.init(rawValue = row.status))
        match.updatedAt = date(row.updatedAt)
        return match
    }

    private fun uuid(value: String): UUID = requireNotNull(UUID(uuidString = value))
    private fun player(value: String): Player = requireNotNull(Player.init(rawValue = value))
    private fun date(millis: Long) = Date(timeIntervalSince1970 = millis.toDouble() / 1000.0)
    private fun millis(date: Date) = (date.timeIntervalSince1970 * 1000.0).toLong()
}
