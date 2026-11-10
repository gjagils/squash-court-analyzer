package com.squashanalyzer.android.live

import android.content.Context
import kotlinx.coroutines.launch
import squash.analyzer.core.TeamAlertFollow
import squash.analyzer.core.TeamAlertPlatform

/**
 * 4.0, T6: Android's half of Core's `TeamAlertFollow`. Whoever takes part in
 * a live team match gets a notification from the live server when a
 * teammate's partij starts or is decided and at the result: an FCM data
 * message `{ kind: "alert", id, server, slot, alertTitle, alertBody }`,
 * shown on the "Uitslagen en games" channel without the ongoing score
 * notification (`LiveFollowMessagingService`).
 */
class AndroidTeamAlertPlatform(private val context: Context) : TeamAlertPlatform {
    override val platform: String = "android"
    override val usesSandbox: Boolean = false

    /** Asks for POST_NOTIFICATIONS (Android 13+); set by MainActivity while it is there */
    var requestNotificationPermission: (suspend () -> Boolean)? = null

    override suspend fun notificationsAllowed(ask: Boolean): Boolean {
        val notifier = LiveScoreNotifier(context)
        if (notifier.canNotify()) return true
        if (!ask) return false
        val asked = requestNotificationPermission?.invoke() ?: false
        return asked && notifier.canNotify()
    }

    override suspend fun pushToken(): String? = FirebaseConfig.token()

    companion object {
        /**
         * The alert of a team match this phone takes part in. Not shown when
         * the setting is off, or when it is about the partij this phone scores
         * or filled in (the server may not have known that yet).
         */
        fun show(context: Context, data: Map<String, String>) {
            val match = FollowedMatch.validated(data["id"], data["server"], FollowedMatch.TEAM) ?: return
            val alert = LiveAlerts.from(data, enabled = true) ?: return
            val slot = data["slot"]?.toIntOrNull() ?: 0
            val appContext = context.applicationContext
            FcmLiveFollowPresenter.scope.launch {
                if (!TeamAlertFollow.shared.shouldShow(teamId = match.id, slot = slot)) return@launch
                LiveScoreNotifier(appContext).alert(match, alert)
            }
        }
    }
}
