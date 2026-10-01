package com.squashanalyzer.android.data

import skip.foundation.Date
import skip.lib.Array as SwiftArray
import squash.analyzer.core.MatchHistoryStore
import squash.analyzer.core.HistoryGameScore
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
        val withBadges = badges.matchIdsWithBadges()
        val coach = matchStore.history().map { match ->
            val games = match.games.mapNotNull { game ->
                game.winner?.let { HistoryGameScore(player1Score = game.player1Score, player2Score = game.player2Score, winner = it) }
            }
            MatchHistorySummary(
                id = match.id, kind = "coach",
                player1Name = match.player1Name, player2Name = match.player2Name,
                player1Games = match.player1GamesBefore + games.count { it.winner == PLAYER1_RAW } + match.player1GamesAfter,
                player2Games = match.player2GamesBefore + games.count { it.winner == PLAYER2_RAW } + match.player2GamesAfter,
                status = match.status, updatedAt = date(match.updatedAt),
                games = SwiftArray(games),
                untrackedBefore = match.player1GamesBefore + match.player2GamesBefore,
                untrackedAfter = match.player1GamesAfter + match.player2GamesAfter,
                bestOf = match.bestOf, hasBadges = match.id in withBadges,
            )
        }
        val referee = refereeMatchStore.history().map { match ->
            val games = match.completedGames.map {
                HistoryGameScore(player1Score = it.player1Score, player2Score = it.player2Score, winner = it.winner)
            }.toMutableList()
            // The deciding game stays on the board until "Volgende game", so it is not among the completed ones
            gameWinner(match.player1Score, match.player2Score)?.let {
                games.add(HistoryGameScore(player1Score = match.player1Score, player2Score = match.player2Score, winner = it))
            }
            MatchHistorySummary(
                id = match.id, kind = "referee",
                player1Name = match.player1Name, player2Name = match.player2Name,
                player1Games = match.player1GamesBefore + games.count { it.winner == PLAYER1_RAW },
                player2Games = match.player2GamesBefore + games.count { it.winner == PLAYER2_RAW },
                status = match.status, updatedAt = date(match.updatedAt),
                games = SwiftArray(games),
                untrackedBefore = match.player1GamesBefore + match.player2GamesBefore,
                bestOf = match.bestOf, hasBadges = match.id in withBadges,
            )
        }
        val merged = (coach + referee).sortedByDescending { it.updatedAt.timeIntervalSince1970 }
        return SwiftArray(merged)
    }

    /** A finished game: 11 or more and two clear (Core's ScoringEngine) */
    private fun gameWinner(p1: Int, p2: Int): String? = when {
        p1 >= 11 && p1 - p2 >= 2 -> PLAYER1_RAW
        p2 >= 11 && p2 - p1 >= 2 -> PLAYER2_RAW
        else -> null
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
