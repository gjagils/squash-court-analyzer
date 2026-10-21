package com.squashanalyzer.android.live

import android.content.Context
import com.squashanalyzer.android.HttpRequest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONObject
import skip.foundation.Data
import skip.foundation.URL
import skip.lib.Dictionary
import squash.analyzer.core.LiveFollow
import squash.analyzer.core.LiveFollowError
import squash.analyzer.core.LiveFollowPresenter
import squash.analyzer.core.LiveFollowTarget
import squash.analyzer.core.LiveSnapshot
import squash.analyzer.core.TeamFollowStand

/**
 * Android's half of "Live score op het vergrendelscherm" (Core's `LiveFollow`):
 * shows the first state as a notification, then registers this device's FCM
 * token with the live server, which pushes every rally
 * (`LiveFollowMessagingService`). Lives as long as the process (set in
 * `SquashApplication`).
 */
class FcmLiveFollowPresenter(private val context: Context) : LiveFollowPresenter {
    override val platform: String = "android"
    override val usesSandbox: Boolean = false

    private val notifier = LiveScoreNotifier(context)
    private val followed = FollowedMatches(context)

    /** Asks the user for POST_NOTIFICATIONS (Android 13+); set by MainActivity while it is there */
    var requestNotificationPermission: (suspend () -> Boolean)? = null

    override suspend fun start(target: LiveFollowTarget, snapshot: LiveSnapshot) {
        val match = FollowedMatch.from(target)
        val score = LiveScoreJson.from(snapshot)
        begin(target, match, show = { notifier.show(match, score) }, fetchPhotos = { notifier.fetchPhotos(match) })
    }

    /** A team match (Competitie): the four partijen in one notification */
    override suspend fun startTeam(target: LiveFollowTarget, stand: TeamFollowStand) {
        val match = FollowedMatch.from(target)
        val score = TeamScore.from(stand, context)
        val slots = TeamScoreCard(score, context).slots
        begin(target, match, show = { notifier.showTeam(match, score) }, fetchPhotos = { notifier.fetchTeamPhotos(match, slots) })
    }

    /** Permission, the first notification, the token to the server; then the photos */
    private suspend fun begin(target: LiveFollowTarget, match: FollowedMatch, show: () -> Unit, fetchPhotos: () -> Unit) {
        if (!FirebaseConfig.isAvailable) throw LiveFollowError.pushUnavailable
        if (!notifier.canNotify()) {
            val asked = requestNotificationPermission?.invoke() ?: false
            if (!asked || !notifier.canNotify()) throw LiveFollowError.notAllowed
        }
        show()
        val token = FirebaseConfig.token()
        if (token == null) {
            notifier.cancel(match)
            throw LiveFollowError.pushUnavailable
        }
        // Registered here first, so a refusal (503: this server cannot push yet,
        // or no network) reaches the user instead of a stand that never changes
        try {
            LiveFollow.shared.register(token, for_ = target)
        } catch (e: Exception) {
            notifier.cancel(match)
            throw e
        }
        followed.add(match)
        followed.token = token
        // Photos of matches no longer followed go; this match's photos come once
        LivePhotos.deleteAllExcept(context, followed.all())
        fetchPhotos()
        // Core keeps the token for unfollow(); it is the same, so the server sees it twice
        scope.launch { LiveFollow.shared.tokenChanged(token, for_ = target) }
    }

    override suspend fun stop(target: LiveFollowTarget) {
        val match = FollowedMatch.from(target)
        followed.remove(match)
        notifier.cancel(match)
        notifier.cancelAlert(match)
        LivePhotos.delete(context, match)
    }

    companion object {
        /** Main thread work for pushes and buttons that outlive a screen */
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

        /**
         * "Stoppen" (or the notification swiped away): off the lock screen and
         * the server forgets this phone. Also works after an app restart, when
         * Core no longer knows the match.
         */
        suspend fun stopFollowing(context: Context, match: FollowedMatch) {
            val followed = FollowedMatches(context)
            val target = match.toTarget()
            val known = LiveFollow.shared.isFollowing(target)
            if (known) {
                LiveFollow.shared.unfollow(target)
            } else {
                followed.remove(match)
                LiveScoreNotifier(context).cancel(match)
                LiveScoreNotifier(context).cancelAlert(match)
                LivePhotos.delete(context, match)
            }
            // Core sends the DELETE only when it still knows the token
            val token = followed.token ?: return
            if (known) return
            val url = URL(string = match.apiUrl + "/followers")
            val body = JSONObject().put("platform", "android").put("token", token).toString()
            val headers = Dictionary<String, String>()
            headers["Content-Type"] = "application/json"
            try {
                HttpRequest.send("DELETE", url, headers,
                    Data(platformValue = body.toByteArray()), 10_000)
            } catch (e: Exception) {
                // No network: the server drops the token when FCM reports it gone, or at the end
            }
        }

        /** A new FCM token: tell the server of every followed match */
        fun tokenChanged(context: Context, token: String) {
            val followed = FollowedMatches(context)
            followed.token = token
            for (match in followed.all()) {
                scope.launch { LiveFollow.shared.tokenChanged(token, for_ = match.toTarget()) }
            }
        }
    }
}
