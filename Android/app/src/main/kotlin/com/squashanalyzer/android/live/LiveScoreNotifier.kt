package com.squashanalyzer.android.live

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.squashanalyzer.android.MainActivity
import com.squashanalyzer.android.R

/**
 * Puts a followed live match on the lock screen. Android 16+: a promoted
 * Live Update (status bar chip, lock screen) with a game bar
 * (Notification.ProgressStyle); before that an ongoing notification whose
 * expanded form is a mini scoreboard. One notification per match.
 */
class LiveScoreNotifier(private val context: Context) {
    companion object {
        const val CHANNEL_ID = "live-score"
        /** Marks a shown final score, so "Uitslag" alerts once and later copies stay silent */
        private const val EXTRA_FINISHED = "squashanalyzer.finished"
        const val PLAYER1_COLOR = 0xFFF28C26.toInt()
        const val PLAYER2_COLOR = 0xFF8094AD.toInt()
        const val SERVE_COLOR = 0xFFFF9926.toInt()
        /** Not played yet on the game bar */
        const val OPEN_COLOR = 0x668A8580
        /** A finished match stays a while on the lock screen, then goes */
        const val FINISHED_TIMEOUT_MILLIS = 3L * 60 * 60 * 1000

        fun notificationId(target: FollowedMatch): Int = ("live-" + target.id).hashCode()
    }

    private val manager = context.getSystemService(NotificationManager::class.java)

    fun canNotify(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
        val channel = manager.getNotificationChannel(CHANNEL_ID)
        return channel == null || channel.importance != NotificationManager.IMPORTANCE_NONE
    }

    private fun ensureChannel() {
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(CHANNEL_ID, "Live score", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "De stand van een wedstrijd die je volgt, op je vergrendelscherm"
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    /** Shows or updates the match; `alert` only for the final score */
    fun show(target: FollowedMatch, score: LiveScore) {
        if (!canNotify()) return
        ensureChannel()
        val card = LiveScoreCard(score)
        // Updates are silent; the final score may sound once
        val alert = card.isFinished && !finishedShown(target)
        val notification = if (Build.VERSION.SDK_INT >= 36) liveUpdate(target, card, alert) else ongoing(target, card, alert)
        notification.extras.putBoolean(EXTRA_FINISHED, card.isFinished)
        try {
            manager.notify(notificationId(target), notification)
        } catch (e: SecurityException) {
            android.util.Log.w("LiveFollow", "Melding niet getoond", e)
        }
    }

    private fun finishedShown(target: FollowedMatch): Boolean = manager.activeNotifications.any { shown ->
        shown.id == notificationId(target) && shown.notification.extras.getBoolean(EXTRA_FINISHED)
    }

    fun cancel(target: FollowedMatch) {
        manager.cancel(notificationId(target))
    }

    private fun openApp(): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun action(target: FollowedMatch, action: String): PendingIntent {
        val intent = Intent(context, LiveFollowActionReceiver::class.java)
            .setAction(action)
            .putExtra(LiveFollowActionReceiver.EXTRA_ID, target.id)
            .putExtra(LiveFollowActionReceiver.EXTRA_SERVER, target.server)
        val code = (action + target.id).hashCode()
        return PendingIntent.getBroadcast(context, code, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun playerColor(player: Int): Int = when (player) {
        1 -> PLAYER1_COLOR
        2 -> PLAYER2_COLOR
        else -> OPEN_COLOR
    }

    /** Android 16+: standard style only (no custom views, not colorized), so it can be promoted */
    @androidx.annotation.RequiresApi(36)
    private fun liveUpdate(target: FollowedMatch, card: LiveScoreCard, alert: Boolean): Notification {
        val style = Notification.ProgressStyle()
            .setStyledByProgress(false)
            .setProgressSegments(card.segments.map { segment ->
                Notification.ProgressStyle.Segment(segment.length).setColor(playerColor(segment.player))
            })
            .setProgress(card.progress)
        // A point at the end of every game keeps the games apart on the bar
        var end = 0
        for (segment in card.segments.dropLast(1)) {
            end += segment.length
            if (end % card.pointsPerGame == 0) {
                style.addProgressPoint(Notification.ProgressStyle.Point(end).setColor(OPEN_COLOR))
            }
        }
        val builder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_live_score)
            .setContentTitle(card.title)
            .setContentText(card.text)
            .setStyle(style)
            .setShortCriticalText(card.chipText)
            .setContentIntent(openApp())
            .setDeleteIntent(action(target, LiveFollowActionReceiver.ACTION_DISMISSED))
            .setOnlyAlertOnce(!alert)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_STATUS)
            .setShowWhen(false)
        if (!alert) {
            // Platform builder has no setSilent: same trick as NotificationCompat
            // (a group whose summary alerts; there is no summary, so nothing sounds)
            builder.setGroup("live-silent").setGroupAlertBehavior(Notification.GROUP_ALERT_SUMMARY)
        }
        if (card.isFinished) {
            builder.setOngoing(false).setAutoCancel(true).setTimeoutAfter(FINISHED_TIMEOUT_MILLIS)
        } else {
            builder.setOngoing(true)
                .addAction(Notification.Action.Builder(null, "Stoppen", action(target, LiveFollowActionReceiver.ACTION_STOP)).build())
            // setRequestPromotedOngoing is API 36.1; the extra works from 36 on
            builder.extras.putBoolean("android.requestPromotedOngoing", true)
        }
        return builder.build()
    }

    /** Android 9-15: an ongoing notification, expanded a mini scoreboard */
    private fun ongoing(target: FollowedMatch, card: LiveScoreCard, alert: Boolean): Notification {
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_live_score)
            .setContentTitle(if (card.isFinished || card.isBetween) card.title else card.scoreLine)
            .setContentText(card.compactText)
            .setCustomBigContentView(scoreboard(card))
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setContentIntent(openApp())
            .setDeleteIntent(action(target, LiveFollowActionReceiver.ACTION_DISMISSED))
            .setOnlyAlertOnce(!alert)
            .setSilent(!alert)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setShowWhen(false)
            .setColor(PLAYER1_COLOR)
        if (card.isFinished) {
            builder.setOngoing(false).setAutoCancel(true).setTimeoutAfter(FINISHED_TIMEOUT_MILLIS)
        } else {
            builder.setOngoing(true)
                .addAction(0, "Stoppen", action(target, LiveFollowActionReceiver.ACTION_STOP))
        }
        return builder.build()
    }

    private fun scoreboard(card: LiveScoreCard): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.notification_live_score)
        val score = card.score
        val serving = score.status == "playing" || score.status == "warmup"
        for (player in 1..2) {
            val name = if (player == 1) R.id.live_name1 else R.id.live_name2
            val points = if (player == 1) R.id.live_score1 else R.id.live_score2
            val pips = if (player == 1) R.id.live_pips1 else R.id.live_pips2
            val serve = if (player == 1) R.id.live_serve1 else R.id.live_serve2
            views.setTextViewText(name, card.name(player))
            views.setTextColor(name, playerColor(player))
            val (won, needed) = card.pips(player)
            views.setTextViewText(pips, "●".repeat(won.coerceAtMost(needed)) + "○".repeat((needed - won).coerceAtLeast(0)))
            views.setTextColor(pips, playerColor(player))
            val value = when {
                card.isFinished -> if (player == 1) score.gamesWon.first else score.gamesWon.second
                card.isBetween -> if (player == 1) score.gamesWon.first else score.gamesWon.second
                else -> if (player == 1) score.score.first else score.score.second
            }
            views.setTextViewText(points, value.toString())
            views.setViewVisibility(serve, if (serving && score.server == player) View.VISIBLE else View.INVISIBLE)
        }
        views.setTextViewText(R.id.live_footer_games, card.footerGames)
        views.setTextViewText(R.id.live_footer_status, card.footerStatus)
        return views
    }
}
