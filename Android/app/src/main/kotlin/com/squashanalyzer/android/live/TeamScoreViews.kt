package com.squashanalyzer.android.live

import android.content.Context
import android.view.View
import android.widget.RemoteViews
import com.squashanalyzer.android.R

/**
 * The custom views of a followed team match on Android 9-15 (design B, 20
 * October 2026): collapsed the teams with their partijen and one line of
 * state; expanded the partij under way large (two at once as rows, or the
 * next partij), the strip E1-E4 and a bar with the teams and their partijen.
 * All four decided: the four results as rows above the bar.
 */
object TeamScoreViews {
    fun collapsed(context: Context, card: TeamScoreCard): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.notification_team_score_small)
        teamLine(views, card)
        views.setTextViewText(R.id.team_compact, card.compactText)
        return views
    }

    fun expanded(context: Context, match: FollowedMatch, card: TeamScoreCard): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.notification_team_score)
        teamLine(views, card)
        // At the end the winner's box filled (SBN rule, as far as the push knows it)
        val winner = if (card.isFinished) card.teamWinner else 0
        show(views, R.id.team_home_games, R.id.team_home_games_won, if (winner == 1) 2 else 1, card.partijenWon.first.toString())
        show(views, R.id.team_away_games, R.id.team_away_games_won, if (winner == 2) 2 else 1, card.partijenWon.second.toString())
        views.setViewVisibility(R.id.team_live_dot, if (card.isFinished) View.INVISIBLE else View.VISIBLE)
        views.removeAllViews(R.id.team_rows)
        views.removeAllViews(R.id.team_strip)
        when (val top = card.focus) {
            is TeamScoreCard.Focus.Finished -> for (row in card.rows) views.addView(R.id.team_rows, row(context, match, row))
            is TeamScoreCard.Focus.Live ->
                if (top.partijen.size > 1) {
                    for (partij in top.partijen.take(2)) views.addView(R.id.team_rows, row(context, match, card.rows[partij.slot - 1]))
                } else {
                    views.addView(R.id.team_rows, focus(context, match, card, top.partijen.first().slot))
                }
            is TeamScoreCard.Focus.Next -> views.addView(R.id.team_rows, focus(context, match, card, top.slot))
        }
        if (card.isFinished) {
            views.setViewVisibility(R.id.team_strip, View.GONE)
        } else {
            views.setViewVisibility(R.id.team_strip, View.VISIBLE)
            for (tile in card.tiles) views.addView(R.id.team_strip, tile(context, tile))
        }
        return views
    }

    private fun teamLine(views: RemoteViews, card: TeamScoreCard) {
        // Unbreakable: the text auto-size would otherwise break "All Inn Squash 8"
        // after a word and clip the rest instead of shrinking it
        views.setTextViewText(R.id.team_home_name, LiveScoreCard.unbreakable(card.score.home))
        views.setTextViewText(R.id.team_away_name, LiveScoreCard.unbreakable(card.score.away))
        views.setTextViewText(R.id.team_home_games, card.partijenWon.first.toString())
        views.setTextViewText(R.id.team_away_games, card.partijenWon.second.toString())
    }

    /** The partij at the top: heading, both players with the points large in the middle */
    private fun focus(context: Context, match: FollowedMatch, card: TeamScoreCard, slot: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.notification_team_focus)
        val partij = card.score.partij(slot)
        val live = partij?.isLive == true
        val pause = partij?.isPause == true
        show(views, R.id.focus_heading_live, R.id.focus_heading, if (live && !pause) 1 else 2, card.focusHeading(slot))
        views.setViewVisibility(R.id.focus_dot, if (live && !pause) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.focus_games, if (live && partij != null) card.gamesText(partij) else "${card.decidedCount} van 4 klaar")
        if (partij == null) {
            views.setViewVisibility(R.id.focus_players, View.GONE)
            views.setViewVisibility(R.id.focus_unknown, View.VISIBLE)
            return views
        }
        when {
            pause -> showPause(views, "pauze")
            live -> {
                views.setTextViewText(R.id.focus_points1, partij.score.first.toString())
                views.setTextViewText(R.id.focus_points2, partij.score.second.toString())
                views.setViewVisibility(R.id.focus_points, View.VISIBLE)
                views.setViewVisibility(R.id.focus_pause, View.GONE)
            }
            else -> showPause(views, "–")
        }
        for (side in 1..2) {
            val name = card.name(partij, side)
            views.setTextViewText(if (side == 1) R.id.focus_name1 else R.id.focus_name2, LiveScoreCard.unbreakable(name))
            views.setViewVisibility(if (side == 1) R.id.focus_serve1 else R.id.focus_serve2,
                if (partij.isServing(side)) View.VISIBLE else View.INVISIBLE)
            avatar(context, match, views, slot, side, name,
                if (side == 1) R.id.focus_photo1 else R.id.focus_photo2, if (side == 1) R.id.focus_initial1 else R.id.focus_initial2)
        }
        return views
    }

    /** One box of the strip E1-E4 */
    private fun tile(context: Context, tile: TeamScoreCard.Tile): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.notification_team_tile)
        val shown = when (tile.kind) {
            1 -> R.id.tile_won1
            2 -> R.id.tile_won2
            4 -> R.id.tile_live
            else -> R.id.tile_plain
        }
        views.setTextViewText(shown, tile.text)
        views.setViewVisibility(shown, View.VISIBLE)
        return views
    }

    /** The photo when there is one, else the first letter */
    private fun avatar(context: Context, match: FollowedMatch, views: RemoteViews, slot: Int, side: Int, name: String, photoView: Int, initialView: Int) {
        val photo = LivePhotos.loadTeam(context, match, slot, side)
        if (photo != null) {
            views.setImageViewBitmap(photoView, photo)
            views.setViewVisibility(photoView, View.VISIBLE)
            views.setViewVisibility(initialView, View.GONE)
        } else {
            views.setTextViewText(initialView, LiveScoreCard.initialOf(name))
            views.setViewVisibility(photoView, View.GONE)
            views.setViewVisibility(initialView, View.VISIBLE)
        }
    }

    private fun row(context: Context, match: FollowedMatch, row: TeamScoreCard.Row): RemoteViews {
        if (row.missing) {
            // Nobody plays this slot yet: "nog niet begonnen" instead of the team names
            val waiting = RemoteViews(context.packageName, R.layout.notification_team_row_wait)
            waiting.setTextViewText(R.id.team_slot, row.label)
            return waiting
        }
        val views = RemoteViews(context.packageName, R.layout.notification_team_row)
        show(views, R.id.team_slot, R.id.team_slot_live, if (row.isLive) 2 else 1, row.label)
        // Names: in the team colours, greyed for a slot without a partij
        show(views, R.id.team_home, R.id.team_home_dim, if (row.missing) 2 else 1, row.home)
        show(views, R.id.team_away, R.id.team_away_dim, if (row.missing) 2 else 1, row.away)
        // Games: the winner's box in the winner's colour, "–" greyed before the start
        val notStarted = row.games1 == "–"
        games(views, R.id.team_g1, R.id.team_g1_won, R.id.team_g1_dim, row.games1,
            when { notStarted -> 3; row.winner == 1 -> 2; else -> 1 })
        games(views, R.id.team_g2, R.id.team_g2_won, R.id.team_g2_dim, row.games2,
            when { notStarted -> 3; row.winner == 2 -> 2; else -> 1 })
        // The points red; "pauze" grey
        show(views, R.id.team_mid, R.id.team_mid_live, if (row.isLive && row.middle != "pauze") 2 else 1, row.middle)
        // Avatars: the photo when there is one, else the first letter; none for an empty slot
        for (side in 1..2) {
            val frame = if (side == 1) R.id.team_avatar1 else R.id.team_avatar2
            if (row.missing) {
                views.setViewVisibility(frame, View.INVISIBLE)
                continue
            }
            avatar(context, match, views, row.slot, side, if (side == 1) row.home else row.away,
                if (side == 1) R.id.team_photo1 else R.id.team_photo2, if (side == 1) R.id.team_initial1 else R.id.team_initial2)
        }
        return views
    }

    /** Shows `text` in the first (1) or second (2) of two views, hides the other */
    /** The grey text in place of the points (focus_points is a row of views, not a text) */
    private fun showPause(views: RemoteViews, text: String) {
        views.setTextViewText(R.id.focus_pause, text)
        views.setViewVisibility(R.id.focus_points, View.GONE)
        views.setViewVisibility(R.id.focus_pause, View.VISIBLE)
    }

    private fun show(views: RemoteViews, first: Int, second: Int, which: Int, text: String) {
        views.setTextViewText(if (which == 1) first else second, text)
        views.setViewVisibility(first, if (which == 1) View.VISIBLE else View.GONE)
        views.setViewVisibility(second, if (which == 2) View.VISIBLE else View.GONE)
    }

    /** 1 plain, 2 won, 3 greyed */
    private fun games(views: RemoteViews, plain: Int, won: Int, dim: Int, text: String, which: Int) {
        val ids = listOf(plain, won, dim)
        for ((index, id) in ids.withIndex()) {
            if (index + 1 == which) views.setTextViewText(id, text)
            views.setViewVisibility(id, if (index + 1 == which) View.VISIBLE else View.GONE)
        }
    }
}
