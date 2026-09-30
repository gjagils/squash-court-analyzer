package com.squashanalyzer.android.data

import skip.foundation.Date
import skip.foundation.UUID
import skip.lib.Array as SwiftArray
import skip.lib.Set as SwiftSet
import squash.analyzer.core.AwardValue
import squash.analyzer.core.BadgeEngine
import squash.analyzer.core.BadgeEngine.CareerMatch
import squash.analyzer.core.BadgeKind
import squash.analyzer.core.BadgeMatchInput
import squash.analyzer.core.Player
import squash.analyzer.core.PlayerBadgeSummaryStore
import squash.analyzer.core.ScoringEngine
import squash.analyzer.core.SquashScore

private val PLAYER1_RAW = Player.player1.rawValue
private val PLAYER2_RAW = Player.player2.rawValue

/**
 * Kotlin counterpart of iOS' `BadgeAwarder`, without CloudKit, kept
 * behaviour-identical so awards shared between the platforms line up:
 * awards live on the player's card with the shared deterministic id, an undone
 * rally removes an award, a deleted award stays deleted, career badges are
 * stored with the match that earned them, and a player without a row in
 * `players` earns nothing.
 */
class BadgeAwardStore(
    private val dao: BadgeAwardDao,
    private val playerDao: PlayerDao,
    private val matchStore: MatchStore,
    private val refereeMatchStore: RefereeMatchStore,
    /** Identifies this install as the awarding coach, like iOS' `BadgeAwarder.installId` */
    private val installId: String,
) : PlayerBadgeSummaryStore {

    /** The card a player's awards live on: `players.cardId ?: players.id`, like iOS' `badgeCardId` */
    suspend fun cardId(playerId: String): String? = playerDao.byId(playerId)?.let { it.cardId ?: it.id }

    suspend fun activeAwards(playerId: String): List<BadgeAwardRecord> {
        val cardId = cardId(playerId) ?: return emptyList()
        return dao.activeForCard(cardId).map(::record)
    }

    override suspend fun badges(forPlayer: String): SwiftArray<BadgeKind> =
        SwiftArray(activeAwards(forPlayer).map { it.badge }.distinct().mapNotNull { BadgeKind.init(rawValue = it) })

    /**
     * Inserts missing awards and removes active ones the rallies no longer
     * support. `players` maps each picked player id (from "Kies speler") to
     * their slot; `names` gives the opponent name stored with each award.
     */
    suspend fun syncAwards(matchId: String, players: List<Pair<String, Player>>, names: Map<Player, String>, input: BadgeMatchInput) {
        val matchUuid = UUID(uuidString = matchId) ?: return
        val engine = BadgeEngine()
        val earnedByPlayer = engine.badges(input)
        val now = System.currentTimeMillis()
        val expected = mutableListOf<BadgeAwardEntity>()
        for ((playerId, player) in players) {
            val cardId = cardId(playerId) ?: continue
            val cardUuid = UUID(uuidString = cardId) ?: continue
            val badges = mutableSetOf<BadgeKind>()
            earnedByPlayer[player]?.let { earned -> for (badge in earned) badges.add(badge) }
            if (input.matchWinner != null) {
                val career = engine.careerBadges(matchUuid, SwiftArray(careerHistory(playerId)), SwiftSet(onceBadges(cardId, matchId)))
                for (badge in career) badges.add(badge)
            }
            for (badge in badges) {
                expected.add(BadgeAwardEntity(
                    id = AwardValue.awardId(cardId = cardUuid, badge = badge, matchId = matchUuid).uuidString,
                    cardId = cardId, badge = badge.rawValue, matchId = matchId, earnedAt = now,
                    opponentName = names[player.opponent] ?: "", awardedBy = installId,
                ))
            }
        }
        dao.syncMatch(matchId, expected)
    }

    /** Once-only badges the card already has from another match */
    private suspend fun onceBadges(cardId: String, exceptMatchId: String): List<BadgeKind> =
        dao.forCard(cardId)
            .filter { it.matchId != exceptMatchId && it.deletedAt == null }
            .mapNotNull { BadgeKind.init(rawValue = it.badge) }
            .filter { it.isOnce }
            .distinct()

    /**
     * The player's decided matches on this device, coach and referee, as iOS'
     * `BadgeAwarder.history(of:)` builds them: only matches with a winner, the
     * head start counted, and the opponent keyed by id or lowercased name.
     */
    private suspend fun careerHistory(playerId: String): List<CareerMatch> {
        val coach = matchStore.history().mapNotNull { match ->
            val slot = slot(playerId, match.player1Id, match.player2Id) ?: return@mapNotNull null
            val gamesToWin = match.bestOf / 2 + 1
            val p1 = match.player1GamesBefore + match.games.count { it.winner == PLAYER1_RAW } + match.player1GamesAfter
            val p2 = match.player2GamesBefore + match.games.count { it.winner == PLAYER2_RAW } + match.player2GamesAfter
            val winner = winner(p1, p2, gamesToWin) ?: return@mapNotNull null
            careerMatch(match.id, match.savedAt, slot, winner,
                points = match.games.sumOf { if (slot == Player.player1) it.player1Score else it.player2Score },
                opponent = if (slot == Player.player1) match.player2Id ?: match.player2Name else match.player1Id ?: match.player1Name)
        }
        val referee = refereeMatchStore.history().mapNotNull { match ->
            val slot = slot(playerId, match.player1Id, match.player2Id) ?: return@mapNotNull null
            val gamesToWin = match.bestOf / 2 + 1
            // The final game stays "current" until confirmed; it counts once it has a winner
            val current = ScoringEngine().winner(SquashScore(player1 = match.player1Score, player2 = match.player2Score))
            val p1 = match.player1GamesBefore + match.completedGames.count { it.winner == PLAYER1_RAW } + (if (current == Player.player1) 1 else 0)
            val p2 = match.player2GamesBefore + match.completedGames.count { it.winner == PLAYER2_RAW } + (if (current == Player.player2) 1 else 0)
            val winner = winner(p1, p2, gamesToWin) ?: return@mapNotNull null
            val completedPoints = match.completedGames.sumOf { if (slot == Player.player1) it.player1Score else it.player2Score }
            val currentPoints = if (current == null) 0 else if (slot == Player.player1) match.player1Score else match.player2Score
            careerMatch(match.id, match.savedAt, slot, winner, points = completedPoints + currentPoints,
                opponent = if (slot == Player.player1) match.player2Id ?: match.player2Name else match.player1Id ?: match.player1Name)
        }
        return coach + referee
    }

    private fun slot(playerId: String, player1Id: String?, player2Id: String?): Player? = when (playerId) {
        player1Id -> Player.player1
        player2Id -> Player.player2
        else -> null
    }

    private fun winner(p1: Int, p2: Int, gamesToWin: Int): Player? = when {
        p1 >= gamesToWin -> Player.player1
        p2 >= gamesToWin -> Player.player2
        else -> null
    }

    private fun careerMatch(id: String, savedAt: Long, slot: Player, winner: Player, points: Int, opponent: String): CareerMatch? {
        val matchId = UUID(uuidString = id) ?: return null
        return CareerMatch(matchId = matchId, date = Date(timeIntervalSince1970 = savedAt.toDouble() / 1000.0),
            won = winner == slot, pointsWon = points, opponentKey = opponent.lowercase())
    }

    private fun record(it: BadgeAwardEntity) =
        BadgeAwardRecord(it.id, it.cardId, it.badge, it.matchId, it.earnedAt, it.opponentName, it.awardedBy, it.deletedAt)
}
