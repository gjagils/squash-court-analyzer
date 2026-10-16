package com.squashanalyzer.android.live

import android.content.Context
import android.view.View
import android.widget.RemoteViews
import com.squashanalyzer.android.R

/**
 * The custom views of a followed team match on Android 9-15 (design
 * "Teamwedstrijd · Android"): collapsed the teams with their games and one
 * line of state, expanded also the four partijen E1-E4.
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
        views.setTextViewText(R.id.team_header, card.header)
        teamLine(views, card)
        views.removeAllViews(R.id.team_rows)
        for (row in card.rows) views.addView(R.id.team_rows, row(context, match, row))
        return views
    }

    private fun teamLine(views: RemoteViews, card: TeamScoreCard) {
        views.setTextViewText(R.id.team_home_name, card.score.home)
        views.setTextViewText(R.id.team_away_name, card.score.away)
        views.setTextViewText(R.id.team_home_games, card.homeGames.toString())
        views.setTextViewText(R.id.team_away_games, card.awayGames.toString())
    }

    private fun row(context: Context, match: FollowedMatch, row: TeamScoreCard.Row): RemoteViews {
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
        show(views, R.id.team_mid, R.id.team_mid_live, if (row.isLive) 2 else 1, row.middle)
        // Avatars: the photo when there is one, else the first letter; none for an empty slot
        for (side in 1..2) {
            val frame = if (side == 1) R.id.team_avatar1 else R.id.team_avatar2
            if (row.missing) {
                views.setViewVisibility(frame, View.INVISIBLE)
                continue
            }
            val photoView = if (side == 1) R.id.team_photo1 else R.id.team_photo2
            val initialView = if (side == 1) R.id.team_initial1 else R.id.team_initial2
            val photo = LivePhotos.loadTeam(context, match, row.slot, side)
            if (photo != null) {
                views.setImageViewBitmap(photoView, photo)
                views.setViewVisibility(photoView, View.VISIBLE)
                views.setViewVisibility(initialView, View.GONE)
            } else {
                views.setTextViewText(initialView, LiveScoreCard.initialOf(if (side == 1) row.home else row.away))
                views.setViewVisibility(photoView, View.GONE)
                views.setViewVisibility(initialView, View.VISIBLE)
            }
        }
        return views
    }

    /** Shows `text` in the first (1) or second (2) of two views, hides the other */
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
