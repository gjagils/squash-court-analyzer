package com.squashanalyzer.android.data

import skip.foundation.Date
import skip.lib.Array as SwiftArray
import squash.analyzer.core.MatchHistoryStore
import squash.analyzer.core.MatchHistorySummary
import squash.analyzer.core.Player

private val PLAYER1_RAW = Player.player1.rawValue
private val PLAYER2_RAW = Player.player2.rawValue

/**
 * Merges completed/abandoned coach and referee matches into one, sorted
 * history list. Games-won counts come straight from each record's game
 * winners rather than restoring a live `Match`/`RefereeMatch` — a head start
 * (`player1GamesBefore`/`player2GamesBefore`) is not added in, an accepted
 * simplification for this summary list.
 */
class RoomMatchHistoryStore(
    private val matchStore: MatchStore,
    private val refereeMatchStore: RefereeMatchStore,
) : MatchHistoryStore {
    override suspend fun loadHistory(): SwiftArray<MatchHistorySummary> {
        val coach = matchStore.history().map { match ->
            MatchHistorySummary(
                id = match.id, kind = "coach",
                player1Name = match.player1Name, player2Name = match.player2Name,
                player1Games = match.games.count { it.winner == PLAYER1_RAW },
                player2Games = match.games.count { it.winner == PLAYER2_RAW },
                status = match.status, updatedAt = date(match.updatedAt),
            )
        }
        val referee = refereeMatchStore.history().map { match ->
            MatchHistorySummary(
                id = match.id, kind = "referee",
                player1Name = match.player1Name, player2Name = match.player2Name,
                player1Games = match.completedGames.count { it.winner == PLAYER1_RAW },
                player2Games = match.completedGames.count { it.winner == PLAYER2_RAW },
                status = match.status, updatedAt = date(match.updatedAt),
            )
        }
        val merged = (coach + referee).sortedByDescending { it.updatedAt.timeIntervalSince1970 }
        return SwiftArray(merged)
    }

    private fun date(millis: Long) = Date(timeIntervalSince1970 = millis.toDouble() / 1000.0)
}
