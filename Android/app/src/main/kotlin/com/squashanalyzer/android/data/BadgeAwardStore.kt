package com.squashanalyzer.android.data

import skip.foundation.Date
import skip.lib.Array as SwiftArray
import skip.lib.Set as SwiftSet
import squash.analyzer.core.BadgeEngine
import squash.analyzer.core.BadgeEngine.CareerMatch
import squash.analyzer.core.BadgeKind
import squash.analyzer.core.BadgeMatchInput
import squash.analyzer.core.Player
import squash.analyzer.core.PlayerBadgeSummaryStore

private val PLAYER1_RAW = Player.player1.rawValue
private val PLAYER2_RAW = Player.player2.rawValue

/**
 * Kotlin reimplementation of `BadgeAwarder.syncAwards`'s diff logic, without
 * CloudKit: computes this match's badges via the shared, pure `BadgeEngine`
 * and replaces the match's award rows with exactly what's currently earned.
 * Also computes career badges (`BadgeKind.isCareer`) live from match history
 * — those are never written to `badge_awards`, since they can change without
 * any single match being saved (e.g. once a threshold like "25 matches
 * played" is crossed by matches that were already stored).
 */
class BadgeAwardStore(
    private val dao: BadgeAwardDao,
    private val matchStore: MatchStore,
    private val refereeMatchStore: RefereeMatchStore,
) : PlayerBadgeSummaryStore {
    suspend fun activeAwards(playerId: String): List<BadgeAwardRecord> =
        dao.activeForPlayer(playerId).map { BadgeAwardRecord(it.id, it.playerId, it.badge, it.matchId, it.earnedAt) }

    override suspend fun badges(forPlayer: String): SwiftArray<BadgeKind> {
        val perMatch = activeAwards(forPlayer).map { it.badge }.distinct().mapNotNull { BadgeKind.init(rawValue = it) }
        val career = careerBadges(forPlayer).toList()
        return SwiftArray((perMatch + career).distinct())
    }

    /** `players` maps each picked player id (from "Kies speler") to their [Player] slot. */
    suspend fun syncAwards(matchId: String, players: List<Pair<String, Player>>, input: BadgeMatchInput) {
        if (players.isEmpty()) return
        val earnedByPlayer = BadgeEngine().badges(input)
        val now = System.currentTimeMillis()
        val current = mutableListOf<BadgeAwardEntity>()
        val currentIds = mutableSetOf<String>()
        for ((playerId, player) in players) {
            val earned = earnedByPlayer[player] ?: continue
            for (badge in earned) {
                val id = "$playerId:${badge.rawValue}:$matchId"
                currentIds.add(id)
                current.add(BadgeAwardEntity(id = id, playerId = playerId, badge = badge.rawValue, matchId = matchId, earnedAt = now))
            }
        }
        dao.replaceForMatch(matchId, current, currentIds)
    }

    /**
     * Unions every career badge the player has ever earned by walking their
     * whole match history in order — `BadgeEngine.careerBadges(in:...)` only
     * reports what a *specific* match pushed the player over a threshold for,
     * so a badge earned several matches ago needs replaying from the start
     * to still show up.
     */
    private suspend fun careerBadges(playerId: String): Set<BadgeKind> {
        val history = careerHistory(playerId).sortedBy { it.date.timeIntervalSince1970 }
        if (history.isEmpty()) return emptySet()
        val historyArray = SwiftArray(history)
        val engine = BadgeEngine()
        val earned = mutableSetOf<BadgeKind>()
        for (match in history) {
            earned.addAll(engine.careerBadges(match.matchId, historyArray, SwiftSet(earned.toList())).toList())
        }
        return earned
    }

    private suspend fun careerHistory(playerId: String): List<CareerMatch> {
        val coach = matchStore.history().mapNotNull { match ->
            val isPlayer1 = match.player1Id == playerId
            val isPlayer2 = match.player2Id == playerId
            if (!isPlayer1 && !isPlayer2) return@mapNotNull null
            val selfWins = match.games.count { it.winner == (if (isPlayer1) PLAYER1_RAW else PLAYER2_RAW) }
            val opponentWins = match.games.count { it.winner == (if (isPlayer1) PLAYER2_RAW else PLAYER1_RAW) }
            val pointsWon = match.games.sumOf { if (isPlayer1) it.player1Score else it.player2Score }
            val opponentKey = (if (isPlayer1) match.player2Id else match.player1Id)
                ?: (if (isPlayer1) match.player2Name else match.player1Name)
            CareerMatch(
                matchId = uuid(match.id), date = date(match.updatedAt),
                won = match.status == "completed" && selfWins > opponentWins,
                pointsWon = pointsWon, opponentKey = opponentKey,
            )
        }
        val referee = refereeMatchStore.history().mapNotNull { match ->
            val isPlayer1 = match.player1Id == playerId
            val isPlayer2 = match.player2Id == playerId
            if (!isPlayer1 && !isPlayer2) return@mapNotNull null
            val selfWins = match.completedGames.count { it.winner == (if (isPlayer1) PLAYER1_RAW else PLAYER2_RAW) }
            val opponentWins = match.completedGames.count { it.winner == (if (isPlayer1) PLAYER2_RAW else PLAYER1_RAW) }
            val pointsWon = match.completedGames.sumOf { if (isPlayer1) it.player1Score else it.player2Score }
            val opponentKey = (if (isPlayer1) match.player2Id else match.player1Id)
                ?: (if (isPlayer1) match.player2Name else match.player1Name)
            CareerMatch(
                matchId = uuid(match.id), date = date(match.updatedAt),
                won = match.status == "completed" && selfWins > opponentWins,
                pointsWon = pointsWon, opponentKey = opponentKey,
            )
        }
        return coach + referee
    }

    private fun uuid(value: String) = requireNotNull(skip.foundation.UUID(uuidString = value))
    private fun date(millis: Long) = Date(timeIntervalSince1970 = millis.toDouble() / 1000.0)
}
