package com.squashanalyzer.android.live

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.drawable.Icon
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.squashanalyzer.android.BuildConfig
import com.squashanalyzer.android.MainActivity
import com.squashanalyzer.android.R
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap

/**
 * Puts a followed live match on the lock screen. Android 16+: a promoted
 * Live Update (status bar chip, lock screen) with a game bar
 * (Notification.ProgressStyle) and both avatars as large icon; before that an
 * ongoing notification in the style of the website's live ticker. One
 * notification per match.
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
        /** Team match bar: a partij under way with nobody ahead */
        const val LEVEL_COLOR = 0xFFB3ADA6.toInt()
        /** A finished match stays a while on the lock screen, then goes */
        const val FINISHED_TIMEOUT_MILLIS = 3L * 60 * 60 * 1000

        fun notificationId(target: FollowedMatch): Int = ("live-" + target.id).hashCode()

        /** Debug builds only: the Android 9-15 notification on Android 16+ as well */
        const val DEBUG_FORCE_ONGOING = "debug-force-ongoing"
        fun debugPrefs(context: Context): android.content.SharedPreferences =
            context.getSharedPreferences("squash-live-debug", Context.MODE_PRIVATE)

        /** The last state shown per match, to show again when its photos arrive */
        private val lastShown = ConcurrentHashMap<String, LiveScore>()
        private val lastShownTeam = ConcurrentHashMap<String, TeamScore>()

        /** "Melding bij elke game": a heads-up notification next to the score, with sound */
        const val ALERT_CHANNEL_ID = "live-alerts"

        /** One alert per match: the next one replaces it */
        fun alertId(target: FollowedMatch): Int = ("alert-" + target.id).hashCode()
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

    /**
     * Shows or updates the match. Updates are silent; the final score sounds
     * once, unless `quiet` (a separate alert with the result came along).
     */
    fun show(target: FollowedMatch, score: LiveScore, quiet: Boolean = false) {
        if (!canNotify()) return
        ensureChannel()
        val card = LiveScoreCard(score)
        val alert = !quiet && card.isFinished && !finishedShown(target)
        val notification = if (Build.VERSION.SDK_INT >= 36 && usesLiveUpdate()) liveUpdate(target, card, alert) else ongoing(target, card, alert)
        notification.extras.putBoolean(EXTRA_FINISHED, card.isFinished)
        try {
            manager.notify(notificationId(target), notification)
        } catch (e: SecurityException) {
            android.util.Log.w("LiveFollow", "Melding niet getoond", e)
        }
        lastShown[target.id] = score
        if (!card.isFinished) fetchPhotos(target)
    }

    /**
     * The players' photos for the avatars, once per followed match (the pushes
     * carry none); shows the last state again when one arrived.
     */
    fun fetchPhotos(target: FollowedMatch) {
        if (!LivePhotos.needsFetch(context, target) || !FollowedMatches(context).contains(target)) return
        val appContext = context.applicationContext
        FcmLiveFollowPresenter.scope.launch {
            if (!LivePhotos.fetch(appContext, target)) return@launch
            val score = lastShown[target.id] ?: return@launch
            if (FollowedMatches(appContext).contains(target)) LiveScoreNotifier(appContext).show(target, score)
        }
    }

    /**
     * Android 16+ gets the Live Update (caller checks the version, so lint
     * sees it). Debug builds can show the older
     * notification there too, for screenshots of Android 9-15 on a new
     * emulator (LiveScoreSampleReceiver, `--es style ongoing`).
     */
    private fun usesLiveUpdate(): Boolean {
        if (BuildConfig.DEBUG && debugPrefs(context).getBoolean(DEBUG_FORCE_ONGOING, false)) return false
        return true
    }

    private fun finishedShown(target: FollowedMatch): Boolean = manager.activeNotifications.any { shown ->
        shown.id == notificationId(target) && shown.notification.extras.getBoolean(EXTRA_FINISHED)
    }

    fun cancel(target: FollowedMatch) {
        manager.cancel(notificationId(target))
        lastShown.remove(target.id)
        lastShownTeam.remove(target.id)
    }

    // A team match (Competitie): the same notification per match, with the
    // four partijen (design "Teamwedstrijd · Android" on the canvas).

    /** Shows or updates a team match; like `show`, the result sounds once unless `quiet` */
    fun showTeam(target: FollowedMatch, score: TeamScore, quiet: Boolean = false) {
        if (!canNotify()) return
        ensureChannel()
        val card = TeamScoreCard(score)
        val alert = !quiet && card.isFinished && !finishedShown(target)
        val notification = if (Build.VERSION.SDK_INT >= 36 && usesLiveUpdate()) teamLiveUpdate(target, card, alert) else teamOngoing(target, card, alert)
        notification.extras.putBoolean(EXTRA_FINISHED, card.isFinished)
        try {
            manager.notify(notificationId(target), notification)
        } catch (e: SecurityException) {
            android.util.Log.w("LiveFollow", "Melding niet getoond", e)
        }
        lastShownTeam[target.id] = score
        if (!card.isFinished) fetchTeamPhotos(target, card.slots)
    }

    /**
     * The players' photos of these partijen, once per slot per follow (a
     * partij that appears later is asked for when a push first shows it);
     * shows the last stand again when one arrived.
     */
    fun fetchTeamPhotos(target: FollowedMatch, slots: List<Int>) {
        if (LivePhotos.teamSlotsToFetch(context, target, slots).isEmpty() || !FollowedMatches(context).contains(target)) return
        val appContext = context.applicationContext
        FcmLiveFollowPresenter.scope.launch {
            if (!LivePhotos.fetchTeam(appContext, target, slots)) return@launch
            val score = lastShownTeam[target.id] ?: return@launch
            if (FollowedMatches(appContext).contains(target)) LiveScoreNotifier(appContext).showTeam(target, score, quiet = true)
        }
    }

    /** Android 16+: title, text, a bar part per partij and the games as chip; standard style so it can be promoted */
    @androidx.annotation.RequiresApi(36)
    private fun teamLiveUpdate(target: FollowedMatch, card: TeamScoreCard, alert: Boolean): Notification {
        val style = Notification.ProgressStyle()
            .setStyledByProgress(false)
            .setProgressSegments(card.segments.map { segment ->
                val color = teamColor(segment.player)
                // Under way: the leader's colour, faded (a progress point or a
                // second segment would split the part: it read as five partijen)
                Notification.ProgressStyle.Segment(segment.length).setColor(if (segment.live) faded(color) else color)
            })
            .setProgress(card.progressMax)
        val builder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_live_score)
            .setContentTitle(card.title)
            .setContentText(card.text)
            .setSubText("Competitie")
            .setStyle(style)
            .setShortCriticalText(card.chipText)
            .setContentIntent(openApp())
            .setDeleteIntent(action(target, LiveFollowActionReceiver.ACTION_DISMISSED))
            .setOnlyAlertOnce(!alert)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_STATUS)
            .setShowWhen(false)
        if (!alert) builder.setGroup("live-silent").setGroupAlertBehavior(Notification.GROUP_ALERT_SUMMARY)
        if (card.isFinished) {
            builder.setOngoing(false).setAutoCancel(true).setTimeoutAfter(FINISHED_TIMEOUT_MILLIS)
        } else {
            builder.setOngoing(true)
                .addAction(Notification.Action.Builder(null, "Stoppen", action(target, LiveFollowActionReceiver.ACTION_STOP)).build())
            builder.extras.putBoolean("android.requestPromotedOngoing", true)
        }
        return builder.build()
    }

    /** Android 9-15: the ongoing notification with the teams and E1-E4 */
    private fun teamOngoing(target: FollowedMatch, card: TeamScoreCard, alert: Boolean): Notification {
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_live_score)
            .setContentTitle(card.title)
            .setContentText(card.compactText)
            .setCustomContentView(TeamScoreViews.collapsed(context, card))
            .setCustomBigContentView(TeamScoreViews.expanded(context, target, card))
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

    /** The bar of a team match: 3 is a partij under way with nobody ahead */
    private fun teamColor(player: Int): Int = if (player == 3) LEVEL_COLOR else playerColor(player)

    /** Half the colour, half grey, opaque (the bar ignores alpha): the partij under way */
    private fun faded(color: Int): Int {
        val grey = 0xFF8A8580.toInt()
        fun mix(shift: Int) = (((color shr shift) and 0xFF) + ((grey shr shift) and 0xFF)) / 2 shl shift
        return (0xFF shl 24) or mix(16) or mix(8) or mix(0)
    }

    // "Melding bij elke game" (LiveAlerts): its own channel with sound and
    // heads-up, so the score itself stays quiet and the user can switch the
    // alerts off in the phone's settings without losing the score.

    private fun ensureAlertChannel() {
        if (manager.getNotificationChannel(ALERT_CHANNEL_ID) != null) return
        val channel = NotificationChannel(ALERT_CHANNEL_ID, "Uitslagen en games", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Een melding als een game of partij gewonnen is en bij de uitslag van een wedstrijd die je volgt"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    /** Shows the alert of a followed match (a game won, the result), replacing its previous alert */
    fun alert(target: FollowedMatch, alert: LiveAlerts.Alert) {
        if (!canNotify()) return
        ensureAlertChannel()
        val notification = NotificationCompat.Builder(context, ALERT_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_live_score)
            .setContentTitle(alert.title)
            .setContentText(alert.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(alert.body))
            .setContentIntent(openApp())
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setColor(PLAYER1_COLOR)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
            .build()
        try {
            manager.notify(alertId(target), notification)
        } catch (e: SecurityException) {
            android.util.Log.w("LiveFollow", "Melding niet getoond", e)
        }
    }

    /** Stopped following: its last alert goes too */
    fun cancelAlert(target: FollowedMatch) {
        manager.cancel(alertId(target))
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
            .putExtra(LiveFollowActionReceiver.EXTRA_KIND, target.kind)
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
        // No progress points: the segments already have gaps, the points drew grey blocks between games
        val builder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_live_score)
            .setContentTitle(card.title)
            .setContentText(card.text)
            .setStyle(style)
            .setShortCriticalText(card.chipText)
            .setLargeIcon(Icon.createWithBitmap(avatarPair(target, card)))
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

    /**
     * Android 9-15: an ongoing notification in the style of the website's live
     * ticker. Collapsed one line with the names, games and points; expanded the
     * whole ticker (avatars, who serves, games, points, finished games).
     */
    private fun ongoing(target: FollowedMatch, card: LiveScoreCard, alert: Boolean): Notification {
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_live_score)
            // Title and text stay for accessibility, the watch and wherever custom views are left out
            .setContentTitle(if (card.isFinished || card.isBetween) card.title else card.scoreLine)
            .setContentText(card.compactText)
            .setCustomContentView(collapsedTicker(card))
            .setCustomBigContentView(ticker(target, card))
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

    /** Collapsed: per player who serves, the name, games won and points */
    private fun collapsedTicker(card: LiveScoreCard): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.notification_live_score_small)
        for (player in 1..2) {
            val first = player == 1
            // Plain names: a cup for the winner would cost the name its room
            views.setTextViewText(if (first) R.id.live_name1 else R.id.live_name2, card.name(player))
            views.setTextViewText(if (first) R.id.live_games1 else R.id.live_games2, card.gamesWon(player).toString())
            views.setTextViewText(if (first) R.id.live_points1 else R.id.live_points2, card.points(player).toString())
            views.setViewVisibility(if (first) R.id.live_serve1 else R.id.live_serve2,
                if (card.serveText(player) != null) View.VISIBLE else View.INVISIBLE)
        }
        return views
    }

    /** The expanded ticker, as live.html: a row per player, finished games as chips */
    private fun ticker(target: FollowedMatch, card: LiveScoreCard): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.notification_live_score)
        views.setTextViewText(R.id.live_status, card.tickerStatus)
        for (player in 1..2) {
            val first = player == 1
            val photo = LivePhotos.load(context, target, player)
            val photoView = if (first) R.id.live_photo1 else R.id.live_photo2
            val initialView = if (first) R.id.live_initial1 else R.id.live_initial2
            if (photo != null) {
                views.setImageViewBitmap(photoView, photo)
                views.setViewVisibility(photoView, View.VISIBLE)
                views.setViewVisibility(initialView, View.GONE)
            } else {
                views.setTextViewText(initialView, card.initial(player))
                views.setViewVisibility(photoView, View.GONE)
                views.setViewVisibility(initialView, View.VISIBLE)
            }
            views.setTextViewText(if (first) R.id.live_name1 else R.id.live_name2, card.tickerName(player))
            val serveView = if (first) R.id.live_serve1 else R.id.live_serve2
            val serve = card.serveText(player)
            views.setTextViewText(serveView, serve ?: "")
            views.setViewVisibility(serveView, if (serve != null) View.VISIBLE else View.GONE)
            views.setTextViewText(if (first) R.id.live_games1 else R.id.live_games2, card.gamesWon(player).toString())
            views.setTextViewText(if (first) R.id.live_points1 else R.id.live_points2, card.points(player).toString())
        }
        views.removeAllViews(R.id.live_history)
        views.removeAllViews(R.id.live_history2)
        val rows = LiveScoreCard.chipRows(card.chips)
        for ((index, row) in rows.withIndex()) {
            for (chip in row) {
                val layout = when (chip.winner) {
                    1 -> R.layout.notification_live_chip1
                    2 -> R.layout.notification_live_chip2
                    else -> R.layout.notification_live_chip0
                }
                val chipView = RemoteViews(context.packageName, layout)
                chipView.setTextViewText(R.id.live_chip, chip.text)
                views.addView(if (index == 0) R.id.live_history else R.id.live_history2, chipView)
            }
        }
        views.setViewVisibility(R.id.live_history, if (rows.isNotEmpty()) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.live_history2, if (rows.size > 1) View.VISIBLE else View.GONE)
        val last = card.score.lastPoint
        views.setTextViewText(R.id.live_last, last ?: "")
        views.setViewVisibility(R.id.live_last, if (last.isNullOrBlank()) View.GONE else View.VISIBLE)
        return views
    }

    /** The Live Update's large icon: both avatars (photo or initial) in one square */
    private fun avatarPair(target: FollowedMatch, card: LiveScoreCard): Bitmap {
        val size = LivePhotos.SIZE
        val avatars = (1..2).map { player ->
            LivePhotos.avatar(LivePhotos.load(context, target, player), card.initial(player), player, size)
        }
        return LivePhotos.pair(avatars[0], avatars[1], size * 3 / 2)
    }
}
