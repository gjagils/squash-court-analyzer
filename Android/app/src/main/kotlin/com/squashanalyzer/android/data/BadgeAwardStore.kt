package com.squashanalyzer.android.data

import skip.lib.Array as SwiftArray
import squash.analyzer.core.BadgeEngine
import squash.analyzer.core.BadgeKind
import squash.analyzer.core.BadgeMatchInput
import squash.analyzer.core.Player
import squash.analyzer.core.PlayerBadgeSummaryStore

/**
 * Kotlin reimplementation of `BadgeAwarder.syncAwards`'s diff logic, without
 * CloudKit: computes this match's badges via the shared, pure `BadgeEngine`
 * and replaces the match's award rows with exactly what's currently earned.
 * Career badges (`BadgeKind.isCareer`) are out of scope here — they need
 * cross-match history, which the Android history browser doesn't have yet.
 */
class BadgeAwardStore(private val dao: BadgeAwardDao) : PlayerBadgeSummaryStore {
    suspend fun activeAwards(playerId: String): List<BadgeAwardRecord> =
        dao.activeForPlayer(playerId).map { BadgeAwardRecord(it.id, it.playerId, it.badge, it.matchId, it.earnedAt) }

    override suspend fun badges(forPlayer: String): SwiftArray<BadgeKind> {
        val kinds = activeAwards(forPlayer).map { it.badge }.distinct().mapNotNull { BadgeKind.init(rawValue = it) }
        return SwiftArray(kinds)
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
}
