package com.squashanalyzer.android.data

import skip.foundation.Date
import skip.lib.Array as SwiftArray
import squash.analyzer.core.MatchHistoryStore
import squash.analyzer.core.MatchHistorySummary
import squash.analyzer.core.Match
import squash.analyzer.core.Player
import squash.analyzer.core.RefereeMatch

private val PLAYER1_RAW = Player.player1.rawValue
private val PLAYER2_RAW = Player.player2.rawValue

/**
 * Merges completed/abandoned coach and referee matches into one, sorted
 * history list. Games won include games played before the app was used and
 * games filled in afterwards ("Uitslag aanvullen"). Opening, deleting and
 * saving go through the coach/referee adapters, so a match restores exactly as
 * when it was played and its badges follow (deleted ones are marked deleted).
 */
class RoomMatchHistoryStore(
    private val matchStore: MatchStore,
    private val refereeMatchStore: RefereeMatchStore,
    private val coach: RoomCoachMatchStore,
    private val referee: RoomRefereeMatchStore,
    private val badges: BadgeAwardStore,
) : MatchHistoryStore {
    override suspend fun loadHistory(): SwiftArray<MatchHistorySummary> {
        val coach = matchStore.history().map { match ->
            MatchHistorySummary(
                id = match.id, kind = "coach",
                player1Name = match.player1Name, player2Name = match.player2Name,
                player1Games = match.player1GamesBefore + match.games.count { it.winner == PLAYER1_RAW } + match.player1GamesAfter,
                player2Games = match.player2GamesBefore + match.games.count { it.winner == PLAYER2_RAW } + match.player2GamesAfter,
                status = match.status, updatedAt = date(match.updatedAt),
            )
        }
        val referee = refereeMatchStore.history().map { match ->
            MatchHistorySummary(
                id = match.id, kind = "referee",
                player1Name = match.player1Name, player2Name = match.player2Name,
                player1Games = match.player1GamesBefore + match.completedGames.count { it.winner == PLAYER1_RAW },
                player2Games = match.player2GamesBefore + match.completedGames.count { it.winner == PLAYER2_RAW },
                status = match.status, updatedAt = date(match.updatedAt),
            )
        }
        val merged = (coach + referee).sortedByDescending { it.updatedAt.timeIntervalSince1970 }
        return SwiftArray(merged)
    }

    override suspend fun coachMatch(id: String): Match? = coach.byId(id)

    override suspend fun refereeMatch(id: String): RefereeMatch? = referee.byId(id)

    override suspend fun saveCoachMatch(match: Match) = coach.save(match)

    override suspend fun delete(entry: MatchHistorySummary) {
        if (entry.kind == "coach") {
            matchStore.byId(entry.id)?.let { matchStore.delete(it) }
        } else {
            refereeMatchStore.byId(entry.id)?.let { refereeMatchStore.delete(it) }
        }
        badges.markMatchDeleted(entry.id)
    }

    private fun date(millis: Long) = Date(timeIntervalSince1970 = millis.toDouble() / 1000.0)
}
