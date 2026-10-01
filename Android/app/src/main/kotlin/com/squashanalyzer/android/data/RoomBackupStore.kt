package com.squashanalyzer.android.data

import androidx.room.withTransaction
import org.json.JSONArray
import skip.foundation.Date
import skip.foundation.UUID
import skip.lib.Array as SwiftArray
import squash.analyzer.core.AwardValue
import squash.analyzer.core.BackupCounts
import squash.analyzer.core.BackupStore
import squash.analyzer.core.BadgeAwardBackupData
import squash.analyzer.core.BadgeKind
import squash.analyzer.core.FullBackup
import squash.analyzer.core.GameExportData
import squash.analyzer.core.LetExportData
import squash.analyzer.core.MatchExportData
import squash.analyzer.core.Player
import squash.analyzer.core.PlayerBackupData
import squash.analyzer.core.PointExportData

/**
 * The Android side of the shared backup file (Core's `FullBackup` /
 * `BackupCodec`, the same file iOS writes): players, coach matches and badge
 * awards out of Room, and back in. Referee matches are not part of the
 * format, on either platform. A restore runs in one transaction.
 *
 * Merging (not replacing) adds only players and matches whose id is not there
 * yet, and merges awards like everywhere else: a deletion always wins. Loose
 * games from old iOS backups (no match) each become a finished match.
 */
class RoomBackupStore(private val db: AppDatabase) : BackupStore {
    private val matches = MatchStore(db.matchDao())

    override suspend fun makeBackup(): FullBackup {
        val players = db.playerDao().all().map { row ->
            PlayerBackupData(
                id = row.id, name = row.name, coachingFocusAreas = SwiftArray(strings(row.coachingFocusAreas)),
                coachingNotes = row.coachingNotes, createdAt = Date(timeIntervalSince1970 = row.createdAt),
                photoBase64 = row.photoData?.let { java.util.Base64.getEncoder().encodeToString(it) }, cardId = row.cardId,
            )
        }
        val awards = db.badgeAwardDao().all().map { row ->
            BadgeAwardBackupData(
                cardId = row.cardId, badge = row.badge, matchId = row.matchId, earnedAt = date(row.earnedAt),
                opponentName = row.opponentName, awardedBy = row.awardedBy, deletedAt = row.deletedAt?.let(::date),
            )
        }
        return FullBackup(
            version = 2, backupDate = Date(), players = SwiftArray(players),
            matches = SwiftArray(matches.all().map(::export)), standaloneGames = SwiftArray(),
            badgeAwards = if (awards.isEmpty()) null else SwiftArray(awards),
        )
    }

    override suspend fun restore(backup: FullBackup, replacing: Boolean): BackupCounts {
        var players = 0
        var restoredMatches = 0
        var games = 0
        var badges = 0
        db.withTransaction {
            if (replacing) {
                db.playerDao().deleteAll()
                db.matchDao().deleteAllMatches()
                db.badgeAwardDao().deleteAll()
            }
            for (player in backup.players) {
                if (db.playerDao().byId(player.id) != null) continue
                db.playerDao().insert(PlayerEntity(
                    id = player.id, name = player.name, coachingFocusAreas = json(player.coachingFocusAreas.toList()),
                    coachingNotes = player.coachingNotes, createdAt = player.createdAt.timeIntervalSince1970,
                    photoData = player.photoBase64?.let { runCatching { java.util.Base64.getDecoder().decode(it) }.getOrNull() },
                    cardId = player.cardId,
                ))
                players++
            }
            val incoming = backup.matches.toList().mapNotNull(::record) +
                backup.standaloneGames.toList().map(::looseGame)
            for (match in incoming) {
                if (db.matchDao().matchById(match.id) != null) continue
                matches.upsert(match)
                restoredMatches++
                games += match.games.size
            }
            for (award in backup.badgeAwards?.toList().orEmpty()) {
                val card = UUID(uuidString = award.cardId) ?: continue
                val match = UUID(uuidString = award.matchId) ?: continue
                val kind = BadgeKind.init(rawValue = award.badge) ?: continue
                val id = AwardValue.awardId(cardId = card, badge = kind, matchId = match).uuidString
                val deletedAt = award.deletedAt?.let(::millis)
                val existing = db.badgeAwardDao().byId(id)
                if (existing == null) {
                    db.badgeAwardDao().insertAll(listOf(BadgeAwardEntity(
                        id = id, cardId = award.cardId, badge = award.badge, matchId = award.matchId,
                        earnedAt = millis(award.earnedAt), opponentName = award.opponentName,
                        awardedBy = award.awardedBy, deletedAt = deletedAt,
                    )))
                    badges++
                } else if (existing.deletedAt == null && deletedAt != null) {
                    db.badgeAwardDao().markDeleted(id, deletedAt)
                }
            }
        }
        return BackupCounts(players = players, matches = restoredMatches, games = games, badges = badges)
    }

    // MARK: Room → backup

    private fun export(match: MatchRecord) = MatchExportData(
        id = match.id, player1Name = match.player1Name, player2Name = match.player2Name,
        savedAt = date(match.savedAt), updatedAt = date(match.updatedAt), matchStartingServer = match.matchStartingServer,
        bestOf = match.bestOf, status = match.status,
        player1CoachingFocus = SwiftArray(match.player1CoachingFocus), player2CoachingFocus = SwiftArray(match.player2CoachingFocus),
        player1CoachingNotes = match.player1CoachingNotes, player2CoachingNotes = match.player2CoachingNotes,
        player1GamesBefore = match.player1GamesBefore, player2GamesBefore = match.player2GamesBefore,
        player1GamesAfter = match.player1GamesAfter, player2GamesAfter = match.player2GamesAfter,
        player1Id = match.player1Id, player2Id = match.player2Id,
        games = SwiftArray(match.games.map { game ->
            GameExportData(
                id = game.id, gameNumber = game.gameNumber, player1Name = game.player1Name, player2Name = game.player2Name,
                player1Score = game.player1Score, player2Score = game.player2Score, startingServer = game.startingServer,
                winner = game.winner, savedAt = date(game.savedAt),
                points = SwiftArray(game.points.map { point ->
                    PointExportData(
                        id = point.id, pointNumber = point.pointNumber, scorer = point.scorer, pointType = point.pointType,
                        zone = point.zone, shotType = point.shotType, server = point.server,
                        player1Score = point.player1Score, player2Score = point.player2Score,
                        duration = point.duration, timestamp = date(point.timestamp),
                        isVolley = if (point.isVolley) true else null,
                    )
                }),
                lets = SwiftArray(game.lets.map { call ->
                    LetExportData(
                        id = call.id, letNumber = call.letNumber, requestedBy = call.requestedBy, server = call.server,
                        player1Score = call.player1Score, player2Score = call.player2Score, timestamp = date(call.timestamp),
                    )
                }),
            )
        }),
    )

    // MARK: backup → Room

    /** Nil for a match without games: there is nothing to resume or show */
    private fun record(data: MatchExportData): MatchRecord? {
        val games = data.games.toList()
        if (games.isEmpty()) return null
        val savedAt = millis(data.savedAt)
        return MatchRecord(
            id = data.id?.takeIf { UUID(uuidString = it) != null } ?: newId(),
            player1Name = data.player1Name, player2Name = data.player2Name,
            matchStartingServer = validPlayer(data.matchStartingServer ?: games.first().startingServer),
            bestOf = data.bestOf ?: 5, savedAt = savedAt, updatedAt = data.updatedAt?.let(::millis) ?: savedAt,
            status = data.status?.takeIf { it in STATUSES } ?: MatchStatus.COMPLETED,
            player1CoachingFocus = data.player1CoachingFocus?.toList().orEmpty(),
            player2CoachingFocus = data.player2CoachingFocus?.toList().orEmpty(),
            player1CoachingNotes = data.player1CoachingNotes ?: "", player2CoachingNotes = data.player2CoachingNotes ?: "",
            player1GamesBefore = data.player1GamesBefore ?: 0, player2GamesBefore = data.player2GamesBefore ?: 0,
            player1GamesAfter = data.player1GamesAfter ?: 0, player2GamesAfter = data.player2GamesAfter ?: 0,
            player1Id = data.player1Id, player2Id = data.player2Id,
            games = games.map(::gameRecord),
        )
    }

    /** The game's own id becomes the match id, so merging the same backup twice adds it once */
    private fun looseGame(game: GameExportData): MatchRecord {
        val savedAt = millis(game.savedAt)
        return MatchRecord(
            id = game.id?.takeIf { UUID(uuidString = it) != null } ?: newId(), player1Name = game.player1Name, player2Name = game.player2Name,
            matchStartingServer = validPlayer(game.startingServer), bestOf = 5, savedAt = savedAt, updatedAt = savedAt,
            status = MatchStatus.COMPLETED, games = listOf(gameRecord(game)),
        )
    }

    private fun gameRecord(game: GameExportData) = GameRecord(
        id = game.id?.takeIf { UUID(uuidString = it) != null } ?: newId(),
        gameNumber = game.gameNumber, player1Name = game.player1Name, player2Name = game.player2Name,
        player1Score = game.player1Score, player2Score = game.player2Score,
        startingServer = validPlayer(game.startingServer), winner = game.winner?.let(::validPlayer),
        savedAt = millis(game.savedAt),
        points = game.points.toList().map { raw ->
            val point = raw.normalized
            PointRecord(
                id = point.id?.takeIf { UUID(uuidString = it) != null } ?: newId(), pointNumber = point.pointNumber,
                scorer = point.scorer, pointType = point.pointType, zone = point.zone, shotType = point.shotType,
                server = point.server, player1Score = point.player1Score, player2Score = point.player2Score,
                timestamp = point.timestamp?.let(::millis) ?: millis(game.savedAt), duration = point.duration,
                isVolley = point.isVolley == true,
            )
        },
        lets = game.lets.toList().map { call ->
            LetRecord(
                id = call.id?.takeIf { UUID(uuidString = it) != null } ?: newId(), letNumber = call.letNumber,
                requestedBy = validPlayer(call.requestedBy), server = validPlayer(call.server),
                player1Score = call.player1Score, player2Score = call.player2Score,
                timestamp = call.timestamp?.let(::millis) ?: millis(game.savedAt),
            )
        },
    )

    private fun validPlayer(raw: String): String = Player.init(rawValue = raw)?.rawValue ?: Player.player1.rawValue
    private fun date(millis: Long) = Date(timeIntervalSince1970 = millis / 1000.0)
    private fun millis(date: Date) = (date.timeIntervalSince1970 * 1000.0).toLong()

    private fun strings(json: String): List<String> = runCatching {
        val array = JSONArray(json)
        (0 until array.length()).map { array.getString(it) }
    }.getOrDefault(emptyList())

    private fun json(values: List<String>): String = JSONArray().apply { values.forEach { put(it) } }.toString()

    companion object {
        private val STATUSES = setOf(MatchStatus.IN_PROGRESS, MatchStatus.COMPLETED, MatchStatus.ABANDONED)
    }
}
