package com.squashanalyzer.android.live

import android.content.Context
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.squashanalyzer.android.BuildConfig
import kotlinx.coroutines.launch
import squash.analyzer.core.LiveFollow

/**
 * The live server's pushes: `data = { kind: "live", id, server, event:
 * "update" | "end", snapshot: "<JSON>" }` after every rally of a followed
 * match, or `{ kind: "team", ..., team: "<JSON>" }` after every change of a
 * followed team match; with `alertTitle` / `alertBody` when a game (partij) is
 * won and at the result. Shows the new state; "end" shows the final score (or
 * removes the notification when there is none) and forgets the match.
 */
class LiveFollowMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        if (BuildConfig.DEBUG) android.util.Log.d("LiveFollow", "Push ${message.data["event"]} voor ${message.data["id"]}")
        handle(applicationContext, message.data)
    }

    override fun onNewToken(token: String) {
        if (BuildConfig.DEBUG) android.util.Log.d("LiveFollow", "FCM token: $token")
        FcmLiveFollowPresenter.scope.launch { FcmLiveFollowPresenter.tokenChanged(applicationContext, token) }
    }

    companion object {
        /** Also the entry point of the debug-only sample broadcast */
        fun handle(context: Context, data: Map<String, String>) {
            val kind = data["kind"]
            if (kind != "live" && kind != FollowedMatch.TEAM) return
            val match = FollowedMatch.validated(data["id"], data["server"], kind) ?: return
            val followed = FollowedMatches(context)
            // A push for a match this phone stopped following (the server may not know yet)
            if (!followed.contains(match)) return
            val notifier = LiveScoreNotifier(context)
            val ended = data["event"] == "end"
            // "Melding bij elke game": a game (partij) won or the result, as a separate heads-up
            val alert = LiveAlerts.from(data, LiveAlerts.isOn(context))
            if (match.isTeam) {
                val stand = TeamScore.parse(data["team"] ?: return) ?: return
                // Ended before all four partijen were decided (stopped, or the alarm): nothing to show any more
                if (ended && !TeamScoreCard(stand).isFinished) notifier.cancel(match)
                else notifier.showTeam(match, stand, quiet = alert != null)
            } else {
                val score = LiveScoreJson.parse(data["snapshot"] ?: return) ?: return
                // Ended without a result (the scorer stopped sharing): nothing to show any more
                if (ended && score.status != "finished") notifier.cancel(match)
                else notifier.show(match, score, quiet = alert != null)
            }
            if (alert != null) notifier.alert(match, alert)
            if (ended) {
                followed.remove(match)
                // The final score keeps its avatars: a notification holds its own copy of the bitmaps
                LivePhotos.delete(context, match)
                FcmLiveFollowPresenter.scope.launch { LiveFollow.shared.forget(match.toTarget()) }
            }
        }
    }
}
